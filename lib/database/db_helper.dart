import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('control_ventas_admin.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _crearTablas,
      onConfigure: (db) async => await db.execute('PRAGMA foreign_keys = ON'),
    );
  }

  Future _crearTablas(Database db, int version) async {
    // 1. Productos
    await db.execute('''
      CREATE TABLE productos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        unidades_por_paquete INTEGER NOT NULL DEFAULT 1,
        costo_paquete REAL NOT NULL DEFAULT 0.0,
        costo_unitario REAL NOT NULL DEFAULT 0.0,
        precio_venta_unidad REAL NOT NULL,
        precio_venta_paquete REAL NOT NULL DEFAULT 0.0,
        stock_unidades INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // 2. Historial de compras
    await db.execute('''
      CREATE TABLE compras (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        producto_id INTEGER NOT NULL,
        paquetes_comprados INTEGER NOT NULL DEFAULT 1,
        unidades_totales INTEGER NOT NULL,
        costo_total REAL NOT NULL DEFAULT 0.0,
        fecha TEXT NOT NULL,
        FOREIGN KEY (producto_id) REFERENCES productos (id) ON DELETE CASCADE
      )
    ''');

    // 3. Ventas realizadas
    await db.execute('''
      CREATE TABLE ventas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        producto_id INTEGER NOT NULL,
        tipo_venta TEXT NOT NULL DEFAULT 'UNIDAD',
        cantidad INTEGER NOT NULL,
        monto_total_cobrado REAL NOT NULL,
        costo_total_aplicado REAL NOT NULL DEFAULT 0.0,
        ganancia_neta REAL NOT NULL,
        fecha TEXT NOT NULL,
        FOREIGN KEY (producto_id) REFERENCES productos (id) ON DELETE CASCADE
      )
    ''');

    // 4. Clientes y deudas (fiados)
    await db.execute('''
      CREATE TABLE deudas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cliente_nombre TEXT NOT NULL,
        producto_id INTEGER NOT NULL,
        tipo_venta TEXT NOT NULL DEFAULT 'UNIDAD',
        cantidad INTEGER NOT NULL,
        monto_adeudado REAL NOT NULL,
        costo_base REAL NOT NULL DEFAULT 0.0,
        estado TEXT NOT NULL DEFAULT 'PENDIENTE',
        fecha_creacion TEXT NOT NULL,
        fecha_pago TEXT,
        FOREIGN KEY (producto_id) REFERENCES productos (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> borrarTodosLosDatos() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('deudas');
      await txn.delete('ventas');
      await txn.delete('compras');
      await txn.delete('productos');
    });
  }

  // --- REGISTRO DE PRODUCTOS Y COMPRAS ---

  Future<List<Map<String, dynamic>>> obtenerProductos() async {
    final db = await database;
    return await db.query('productos', orderBy: 'nombre ASC');
  }

  Future<int> agregarProducto({
    required String nombre,
    required double precioVentaUnidad,
    int stockInicialUnidades = 0,
  }) async {
    final db = await database;

    int productoId = 0;
    await db.transaction((txn) async {
      productoId = await txn.insert('productos', {
        'nombre': nombre,
        'unidades_por_paquete': 1,
        'costo_paquete': 0.0,
        'costo_unitario': 0.0,
        'precio_venta_unidad': precioVentaUnidad,
        'precio_venta_paquete': 0.0,
        'stock_unidades': stockInicialUnidades,
      });

      if (stockInicialUnidades > 0) {
        await txn.insert('compras', {
          'producto_id': productoId,
          'paquetes_comprados': 1,
          'unidades_totales': stockInicialUnidades,
          'costo_total': 0.0,
          'fecha': DateTime.now().toIso8601String(),
        });
      }
    });

    return productoId;
  }

  Future<void> editarProducto({
    required int id,
    required String nombre,
    required double precioVentaUnidad,
    required int stockUnidades,
  }) async {
    final db = await database;
    await db.update(
      'productos',
      {
        'nombre': nombre,
        'unidades_por_paquete': 1,
        'costo_paquete': 0.0,
        'costo_unitario': 0.0,
        'precio_venta_unidad': precioVentaUnidad,
        'precio_venta_paquete': 0.0,
        'stock_unidades': stockUnidades,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- VENTAS INMEDIATAS (INDIVIDUALES Y MÚLTIPLES) ---

  Future<void> registrarVentaDirecta({
    required int productoId,
    String tipoVenta = 'UNIDAD',
    required int cantidad,
  }) async {
    final db = await database;
    final List<Map<String, dynamic>> res = await db.query(
      'productos',
      where: 'id = ?',
      whereArgs: [productoId],
    );

    if (res.isEmpty) return;
    final producto = res.first;

    final int unidadesADescontar = cantidad;
    final double precioUnit = (producto['precio_venta_unidad'] as num?)?.toDouble() ?? 0.0;
    final double costoUnit = (producto['costo_unitario'] as num?)?.toDouble() ?? 0.0;

    final double montoCobrado = cantidad * precioUnit;
    final double costoAplicado = cantidad * costoUnit;
    final double ganancia = montoCobrado - costoAplicado;

    await db.transaction((txn) async {
      await txn.insert('ventas', {
        'producto_id': productoId,
        'tipo_venta': tipoVenta,
        'cantidad': cantidad,
        'monto_total_cobrado': montoCobrado,
        'costo_total_aplicado': costoAplicado,
        'ganancia_neta': ganancia,
        'fecha': DateTime.now().toIso8601String(),
      });

      await txn.rawUpdate('''
        UPDATE productos 
        SET stock_unidades = stock_unidades - ? 
        WHERE id = ?
      ''', [unidadesADescontar, productoId]);
    });
  }

  Future<void> registrarVentaMultiple(List<Map<String, dynamic>> items) async {
    final db = await database;
    final ahora = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      for (var item in items) {
        final int productoId = item['producto_id'] as int;
        final int cantidad = item['cantidad'] as int;
        final double montoCobrado = (item['monto_total_cobrado'] as num?)?.toDouble() ?? 0.0;
        final double costoAplicado = (item['costo_total_aplicado'] as num?)?.toDouble() ?? 0.0;
        final double ganancia = (item['ganancia_neta'] as num?)?.toDouble() ?? 0.0;

        await txn.insert('ventas', {
          'producto_id': productoId,
          'tipo_venta': 'UNIDAD',
          'cantidad': cantidad,
          'monto_total_cobrado': montoCobrado,
          'costo_total_aplicado': costoAplicado,
          'ganancia_neta': ganancia,
          'fecha': ahora,
        });

        await txn.rawUpdate('''
          UPDATE productos 
          SET stock_unidades = stock_unidades - ? 
          WHERE id = ?
        ''', [cantidad, productoId]);
      }
    });
  }

  // --- MÓDULO DE DEUDAS (FIADOS) ---

  Future<void> registrarDeuda({
    required String cliente,
    required int productoId,
    String tipoVenta = 'UNIDAD',
    required int cantidad,
  }) async {
    final db = await database;
    final res = await db.query('productos', where: 'id = ?', whereArgs: [productoId]);
    if (res.isEmpty) return;
    final producto = res.first;

    final int unidadesADescontar = cantidad;
    final double precioUnit = (producto['precio_venta_unidad'] as num?)?.toDouble() ?? 0.0;
    final double costoUnit = (producto['costo_unitario'] as num?)?.toDouble() ?? 0.0;

    final double montoAdeudadoNuevo = cantidad * precioUnit;
    final double costoBaseNuevo = cantidad * costoUnit;

    final deudasExistentes = await db.query(
      'deudas',
      where: 'cliente_nombre = ? AND producto_id = ? AND estado = ?',
      whereArgs: [cliente, productoId, 'PENDIENTE'],
    );

    await db.transaction((txn) async {
      if (deudasExistentes.isNotEmpty) {
        final deudaExistente = deudasExistentes.first;
        final int idExistente = deudaExistente['id'] as int;
        final int cantActual = (deudaExistente['cantidad'] as num?)?.toInt() ?? 0;
        final double montoActual = (deudaExistente['monto_adeudado'] as num?)?.toDouble() ?? 0.0;
        final double costoActual = (deudaExistente['costo_base'] as num?)?.toDouble() ?? 0.0;

        await txn.update(
          'deudas',
          {
            'cantidad': cantActual + cantidad,
            'monto_adeudado': montoActual + montoAdeudadoNuevo,
            'costo_base': costoActual + costoBaseNuevo,
            'fecha_creacion': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [idExistente],
        );
      } else {
        await txn.insert('deudas', {
          'cliente_nombre': cliente,
          'producto_id': productoId,
          'tipo_venta': tipoVenta,
          'cantidad': cantidad,
          'monto_adeudado': montoAdeudadoNuevo,
          'costo_base': costoBaseNuevo,
          'estado': 'PENDIENTE',
          'fecha_creacion': DateTime.now().toIso8601String(),
        });
      }

      await txn.rawUpdate('''
        UPDATE productos 
        SET stock_unidades = stock_unidades - ? 
        WHERE id = ?
      ''', [unidadesADescontar, productoId]);
    });
  }

  Future<void> aumentarDeudaCliente({
    required String clienteNombre,
    required int productoId,
    String tipoVenta = 'UNIDAD',
    required int cantidad,
  }) async {
    await registrarDeuda(
      cliente: clienteNombre,
      productoId: productoId,
      tipoVenta: tipoVenta,
      cantidad: cantidad,
    );
  }

  Future<void> restarDeudaItem({
    required int deudaId,
    required double montoARestar,
  }) async {
    final db = await database;
    final res = await db.query('deudas', where: 'id = ?', whereArgs: [deudaId]);
    if (res.isEmpty) return;

    final deuda = res.first;
    final double montoActual = (deuda['monto_adeudado'] as num?)?.toDouble() ?? 0.0;
    final double nuevoMonto = (montoActual - montoARestar).clamp(0.0, double.infinity);

    if (nuevoMonto <= 0.01) {
      await db.update(
        'deudas',
        {'monto_adeudado': 0.0, 'estado': 'PAGADO', 'fecha_pago': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [deudaId],
      );
    } else {
      await db.update(
        'deudas',
        {'monto_adeudado': nuevoMonto},
        where: 'id = ?',
        whereArgs: [deudaId],
      );
    }
  }

  Future<void> restarDeudaCliente({
    required String clienteNombre,
    required double montoARestar,
  }) async {
    final db = await database;
    final deudas = await db.query(
      'deudas',
      where: 'cliente_nombre = ? AND estado = ?',
      whereArgs: [clienteNombre, 'PENDIENTE'],
      orderBy: 'id DESC',
    );

    double restante = montoARestar;
    for (var d in deudas) {
      if (restante <= 0) break;
      final id = d['id'] as int;
      final montoAdeudado = (d['monto_adeudado'] as num?)?.toDouble() ?? 0.0;
      if (restante >= montoAdeudado) {
        await db.update('deudas', {'monto_adeudado': 0.0, 'estado': 'PAGADO'}, where: 'id = ?', whereArgs: [id]);
        restante -= montoAdeudado;
      } else {
        await db.update('deudas', {'monto_adeudado': montoAdeudado - restante}, where: 'id = ?', whereArgs: [id]);
        restante = 0;
      }
    }
  }

  Future<void> saldarDeudasCliente(String clienteNombre) async {
    final db = await database;
    final deudas = await db.query(
      'deudas',
      where: 'cliente_nombre = ? AND estado = ?',
      whereArgs: [clienteNombre, 'PENDIENTE'],
    );
    for (var d in deudas) {
      await saldarDeuda(d['id'] as int);
    }
  }

  Future<void> saldarDeudasClienteParcial(String clienteNombre, double montoAbono) async {
    final db = await database;
    final deudas = await db.query(
      'deudas',
      where: 'cliente_nombre = ? AND estado = ?',
      whereArgs: [clienteNombre, 'PENDIENTE'],
      orderBy: 'id ASC',
    );

    double restante = montoAbono;
    for (var d in deudas) {
      if (restante <= 0) break;
      final id = d['id'] as int;
      final montoAdeudado = (d['monto_adeudado'] as num?)?.toDouble() ?? 0.0;
      if (restante >= montoAdeudado) {
        await saldarDeuda(id);
        restante -= montoAdeudado;
      } else {
        await saldarDeudaParcial(id, restante);
        restante = 0;
      }
    }
  }

  Future<void> saldarDeuda(int deudaId) async {
    final db = await database;
    final res = await db.query('deudas', where: 'id = ?', whereArgs: [deudaId]);
    if (res.isEmpty) return;

    final deuda = res.first;
    final double monto = (deuda['monto_adeudado'] as num?)?.toDouble() ?? 0.0;
    final double costo = (deuda['costo_base'] as num?)?.toDouble() ?? 0.0;
    final ganancia = monto - costo;
    final ahora = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      await txn.update(
        'deudas',
        {'estado': 'PAGADO', 'fecha_pago': ahora},
        where: 'id = ?',
        whereArgs: [deudaId],
      );

      await txn.insert('ventas', {
        'producto_id': deuda['producto_id'],
        'tipo_venta': deuda['tipo_venta'],
        'cantidad': deuda['cantidad'],
        'monto_total_cobrado': monto,
        'costo_total_aplicado': costo,
        'ganancia_neta': ganancia,
        'fecha': ahora,
      });
    });
  }

  Future<void> saldarDeudaParcial(int deudaId, double montoAbono) async {
    final db = await database;
    final res = await db.query('deudas', where: 'id = ?', whereArgs: [deudaId]);
    if (res.isEmpty) return;

    final deuda = res.first;
    final double montoTotalDeuda = (deuda['monto_adeudado'] as num?)?.toDouble() ?? 0.0;
    final double costoTotalDeuda = (deuda['costo_base'] as num?)?.toDouble() ?? 0.0;

    if (montoAbono >= montoTotalDeuda) {
      await saldarDeuda(deudaId);
      return;
    }

    final factor = montoTotalDeuda > 0 ? (montoAbono / montoTotalDeuda) : 0.0;
    final costoAbonado = costoTotalDeuda * factor;
    final gananciaAbono = montoAbono - costoAbonado;
    final ahora = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      await txn.update(
        'deudas',
        {
          'monto_adeudado': montoTotalDeuda - montoAbono,
          'costo_base': costoTotalDeuda - costoAbonado,
        },
        where: 'id = ?',
        whereArgs: [deudaId],
      );

      await txn.insert('ventas', {
        'producto_id': deuda['producto_id'],
        'tipo_venta': deuda['tipo_venta'],
        'cantidad': 1,
        'monto_total_cobrado': montoAbono,
        'costo_total_aplicado': costoAbonado,
        'ganancia_neta': gananciaAbono,
        'fecha': ahora,
      });
    });
  }

  // --- CONSULTAS DASHBOARD, GRÁFICOS Y MESES ---

  Future<List<Map<String, dynamic>>> obtenerClientesDeudores() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT 
        cliente_nombre,
        COALESCE(SUM(monto_adeudado), 0.0) AS total_deuda,
        COUNT(id) AS cantidad_items,
        MAX(fecha_creacion) AS fecha_creacion
      FROM deudas
      WHERE estado = 'PENDIENTE'
      GROUP BY cliente_nombre
      ORDER BY fecha_creacion DESC
    ''');
  }

  Future<List<Map<String, dynamic>>> obtenerDetalleDeudasCliente(String clienteNombre) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT 
        MIN(d.id) AS id,
        d.cliente_nombre,
        d.producto_id,
        d.tipo_venta,
        COALESCE(SUM(d.cantidad), 0) AS cantidad,
        COALESCE(SUM(d.monto_adeudado), 0.0) AS monto_adeudado,
        COALESCE(SUM(d.costo_base), 0.0) AS costo_base,
        d.estado,
        MAX(d.fecha_creacion) AS fecha_creacion,
        p.nombre AS producto_nombre
      FROM deudas d
      INNER JOIN productos p ON d.producto_id = p.id
      WHERE d.cliente_nombre = ? AND d.estado = 'PENDIENTE'
      GROUP BY d.cliente_nombre, d.producto_id
      ORDER BY MAX(d.id) DESC
    ''', [clienteNombre]);
  }

  Future<List<Map<String, dynamic>>> obtenerVentasDelDia() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT v.*, p.nombre AS producto_nombre
      FROM ventas v
      INNER JOIN productos p ON v.producto_id = p.id
      WHERE date(v.fecha) = date('now')
      ORDER BY v.id DESC
    ''');
  }

  Future<Map<String, dynamic>> obtenerMetricasDashboard({
    int? mesFiltro,
    int? anioFiltro,
    DateTime? fechaFiltro,
  }) async {
    final db = await database;

    String whereHoy = "date(fecha) = date('now')";
    if (fechaFiltro != null) {
      final fStr = "${fechaFiltro.year}-${fechaFiltro.month.toString().padLeft(2, '0')}-${fechaFiltro.day.toString().padLeft(2, '0')}";
      whereHoy = "date(fecha) = '$fStr'";
    }

    final resHoy = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(monto_total_cobrado), 0) AS total_ventas,
        COALESCE(SUM(ganancia_neta), 0) AS ganancia_total,
        COALESCE(SUM(cantidad), 0) AS unidades_vendidas
      FROM ventas 
      WHERE $whereHoy
    ''');

    final resSemanal = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(monto_total_cobrado), 0) AS total_ventas,
        COALESCE(SUM(ganancia_neta), 0) AS ganancia_total
      FROM ventas 
      WHERE date(fecha) >= date('now', '-7 days')
    ''');

    String whereMes = "strftime('%Y-%m', fecha) = strftime('%Y-%m', 'now')";
    if (mesFiltro != null && anioFiltro != null) {
      final mStr = mesFiltro.toString().padLeft(2, '0');
      whereMes = "strftime('%Y-%m', fecha) = '$anioFiltro-$mStr'";
    }

    final resMensual = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(monto_total_cobrado), 0) AS total_ventas,
        COALESCE(SUM(ganancia_neta), 0) AS ganancia_total
      FROM ventas 
      WHERE $whereMes
    ''');

    final resDeudas = await db.rawQuery('''
      SELECT COALESCE(SUM(monto_adeudado), 0) AS total_por_cobrar
      FROM deudas
      WHERE estado = 'PENDIENTE'
    ''');

    return {
      'ventas_hoy': resHoy.first['total_ventas'],
      'ganancia_hoy': resHoy.first['ganancia_total'],
      'unidades_hoy': resHoy.first['unidades_vendidas'],
      'ventas_semana': resSemanal.first['total_ventas'],
      'ganancia_semana': resSemanal.first['ganancia_total'],
      'ventas_mes': resMensual.first['total_ventas'],
      'ganancia_mes': resMensual.first['ganancia_total'],
      'por_cobrar': resDeudas.first['total_por_cobrar'],
    };
  }

  Future<Map<String, dynamic>> obtenerMetricasMes(int mes, int anio) async {
    final db = await database;
    final mesStr = mes.toString().padLeft(2, '0');
    final periodoStr = '$anio-$mesStr';

    final res = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(monto_total_cobrado), 0) AS total_ventas,
        COALESCE(SUM(ganancia_neta), 0) AS ganancia_total,
        COALESCE(SUM(cantidad), 0) AS unidades_vendidas
      FROM ventas 
      WHERE strftime('%Y-%m', fecha) = ?
    ''', [periodoStr]);

    return {
      'total_ventas': res.first['total_ventas'],
      'ganancia_total': res.first['ganancia_total'],
      'unidades_vendidas': res.first['unidades_vendidas'],
    };
  }

  Future<List<Map<String, dynamic>>> obtenerVentasPorDiaSemana() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT 
        date(fecha) AS fecha_dia,
        COALESCE(SUM(monto_total_cobrado), 0) AS total_ventas,
        COALESCE(SUM(ganancia_neta), 0) AS ganancia_total
      FROM ventas
      WHERE date(fecha) >= date('now', '-6 days')
      GROUP BY date(fecha)
      ORDER BY date(fecha) ASC
    ''');
  }

  Future<List<Map<String, dynamic>>> obtenerProductosMasVendidos() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT 
        p.nombre AS producto_nombre,
        COALESCE(SUM(v.cantidad), 0) AS total_unidades,
        COALESCE(SUM(v.monto_total_cobrado), 0) AS total_ventas,
        COALESCE(SUM(v.ganancia_neta), 0) AS ganancia_total
      FROM ventas v
      INNER JOIN productos p ON v.producto_id = p.id
      GROUP BY p.id, p.nombre
      ORDER BY total_unidades DESC
      LIMIT 5
    ''');
  }
}