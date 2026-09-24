import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'db_helper.dart';

class SyncManager {
  factory SyncManager() => instance;
  SyncManager._internal();
  static final SyncManager instance = SyncManager._internal();

  bool _initialized = false;
  final dbHelper = DatabaseHelper.instance;

  Future<void> initFirebaseAndSync(Function() onDataChanged) async {
    if (_initialized) return;

    try {
      await Firebase.initializeApp();
      _initialized = true;

      // Sincronización inicial para nuevas instalaciones en otros celulares
      await _sincronizarTodoInicial(onDataChanged);

      _escucharProductosEnNube(onDataChanged);
      _escucharVentasEnNube(onDataChanged);
      _escucharDeudasEnNube(onDataChanged);
      _escucharYapeEnNube(onDataChanged);
      _escucharUsuariosEnNube(onDataChanged);
    } catch (e) {
      // Continuar localmente si falla
    }
  }

  Future<Map<String, dynamic>?> obtenerControlVersionNube() async {
    try {
      if (!_initialized) {
        await Firebase.initializeApp();
        _initialized = true;
      }
      final docRef = FirebaseFirestore.instance.collection('configuracion_app').doc('version_control');
      final doc = await docRef.get();

      final configInicial = {
        'version_minima_code': 1,
        'version_minima_nombre': '1.0.0',
        'actualizacion_forzada': false,
        'mensaje_actualizacion': 'Hemos realizado mejoras importantes en la aplicación. Por favor actualiza a la última versión para continuar usándola.',
        'url_descarga': '',
      };

      if (!doc.exists) {
        await docRef.set(configInicial);
        return configInicial;
      }
      return doc.data();
    } catch (_) {
      return null;
    }
  }

  Future<void> _sincronizarTodoInicial(Function() onDataChanged) async {
    try {
      final prods = await FirebaseFirestore.instance.collection('productos').get();
      for (var doc in prods.docs) {
        final data = doc.data();
        final int id = int.tryParse(doc.id) ?? (data['id'] as int? ?? 0);
        final String nombre = data['nombre']?.toString() ?? '';
        final double precio = (data['precio_venta_unidad'] as num?)?.toDouble() ?? 0.0;
        final int stock = (data['stock_unidades'] as num?)?.toInt() ?? 0;

        if (id > 0 && nombre.isNotEmpty) {
          await dbHelper.sincronizarProductoLocal(
            id: id,
            nombre: nombre,
            precioVentaUnidad: precio,
            stockUnidades: stock,
          );
        }
      }

      final vts = await FirebaseFirestore.instance.collection('ventas').get();
      for (var doc in vts.docs) {
        final data = doc.data();
        await dbHelper.sincronizarVentaLocal(
          docId: doc.id,
          productoId: (data['producto_id'] as num?)?.toInt() ?? 0,
          tipoVenta: data['tipo_venta']?.toString() ?? 'UNIDAD',
          cantidad: (data['cantidad'] as num?)?.toInt() ?? 1,
          montoTotalCobrado: (data['monto_total_cobrado'] as num?)?.toDouble() ?? 0.0,
          costoTotalAplicado: (data['costo_total_aplicado'] as num?)?.toDouble() ?? 0.0,
          gananciaNeta: (data['ganancia_neta'] as num?)?.toDouble() ?? 0.0,
          fecha: data['fecha']?.toString() ?? DateTime.now().toIso8601String(),
        );
      }

      final dds = await FirebaseFirestore.instance.collection('deudas').get();
      for (var doc in dds.docs) {
        final data = doc.data();
        await dbHelper.sincronizarDeudaLocal(
          docId: doc.id,
          clienteNombre: data['cliente_nombre']?.toString() ?? '',
          productoId: (data['producto_id'] as num?)?.toInt() ?? 0,
          cantidad: (data['cantidad'] as num?)?.toInt() ?? 1,
          montoAdeudado: (data['monto_adeudado'] as num?)?.toDouble() ?? 0.0,
          costoBase: (data['costo_base'] as num?)?.toDouble() ?? 0.0,
          estado: data['estado']?.toString() ?? 'PENDIENTE',
          fechaCreacion: data['fecha_creacion']?.toString() ?? DateTime.now().toIso8601String(),
        );
      }

      final ypDoc = await FirebaseFirestore.instance.collection('configuracion_app').doc('yape').get();
      if (ypDoc.exists && ypDoc.data() != null) {
        final data = ypDoc.data()!;
        await dbHelper.sincronizarDatosYapeLocal(
          nombre: data['yape_nombre']?.toString() ?? '',
          numero: data['yape_numero']?.toString() ?? '',
          base64Img: data['yape_qr_base64']?.toString() ?? '',
        );
      }

      final usrs = await FirebaseFirestore.instance.collection('usuarios').get();
      for (var doc in usrs.docs) {
        final data = doc.data();
        await dbHelper.sincronizarUsuarioLocal(
          usuario: doc.id,
          password: data['password']?.toString() ?? '',
          rol: data['rol']?.toString() ?? 'VENDEDOR',
        );
      }

      onDataChanged();
    } catch (_) {}
  }

  void _escucharProductosEnNube(Function() onDataChanged) {
    FirebaseFirestore.instance.collection('productos').snapshots().listen((snapshot) async {
      for (var doc in snapshot.docChanges) {
        if (doc.type == DocumentChangeType.added || doc.type == DocumentChangeType.modified) {
          final data = doc.doc.data();
          if (data != null) {
            final int id = int.tryParse(doc.doc.id) ?? (data['id'] as int? ?? 0);
            final String nombre = data['nombre']?.toString() ?? '';
            final double precio = (data['precio_venta_unidad'] as num?)?.toDouble() ?? 0.0;
            final int stock = (data['stock_unidades'] as num?)?.toInt() ?? 0;

            if (id > 0 && nombre.isNotEmpty) {
              await dbHelper.sincronizarProductoLocal(
                id: id,
                nombre: nombre,
                precioVentaUnidad: precio,
                stockUnidades: stock,
              );
            }
          }
        }
      }
      onDataChanged();
    });
  }

  void _escucharVentasEnNube(Function() onDataChanged) {
    FirebaseFirestore.instance.collection('ventas').snapshots().listen((snapshot) async {
      for (var doc in snapshot.docChanges) {
        if (doc.type == DocumentChangeType.added) {
          final data = doc.doc.data();
          if (data != null) {
            final String docId = doc.doc.id;
            await dbHelper.sincronizarVentaLocal(
              docId: docId,
              productoId: (data['producto_id'] as num?)?.toInt() ?? 0,
              tipoVenta: data['tipo_venta']?.toString() ?? 'UNIDAD',
              cantidad: (data['cantidad'] as num?)?.toInt() ?? 1,
              montoTotalCobrado: (data['monto_total_cobrado'] as num?)?.toDouble() ?? 0.0,
              costoTotalAplicado: (data['costo_total_aplicado'] as num?)?.toDouble() ?? 0.0,
              gananciaNeta: (data['ganancia_neta'] as num?)?.toDouble() ?? 0.0,
              fecha: data['fecha']?.toString() ?? DateTime.now().toIso8601String(),
            );
          }
        }
      }
      onDataChanged();
    });
  }

  void _escucharDeudasEnNube(Function() onDataChanged) {
    FirebaseFirestore.instance.collection('deudas').snapshots().listen((snapshot) async {
      for (var doc in snapshot.docChanges) {
        final data = doc.doc.data();
        if (data != null) {
          final String docId = doc.doc.id;
          await dbHelper.sincronizarDeudaLocal(
            docId: docId,
            clienteNombre: data['cliente_nombre']?.toString() ?? '',
            productoId: (data['producto_id'] as num?)?.toInt() ?? 0,
            cantidad: (data['cantidad'] as num?)?.toInt() ?? 1,
            montoAdeudado: (data['monto_adeudado'] as num?)?.toDouble() ?? 0.0,
            costoBase: (data['costo_base'] as num?)?.toDouble() ?? 0.0,
            estado: data['estado']?.toString() ?? 'PENDIENTE',
            fechaCreacion: data['fecha_creacion']?.toString() ?? DateTime.now().toIso8601String(),
          );
        }
      }
      onDataChanged();
    });
  }

  void _escucharYapeEnNube(Function() onDataChanged) {
    FirebaseFirestore.instance
        .collection('configuracion_app')
        .doc('yape')
        .snapshots()
        .listen((doc) async {
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        await dbHelper.sincronizarDatosYapeLocal(
          nombre: data['yape_nombre']?.toString() ?? '',
          numero: data['yape_numero']?.toString() ?? '',
          base64Img: data['yape_qr_base64']?.toString() ?? '',
        );
        onDataChanged();
      }
    });
  }

  void _escucharUsuariosEnNube(Function() onDataChanged) {
    FirebaseFirestore.instance.collection('usuarios').snapshots().listen((snapshot) async {
      for (var doc in snapshot.docChanges) {
        final data = doc.doc.data();
        if (data != null) {
          await dbHelper.sincronizarUsuarioLocal(
            usuario: doc.doc.id,
            password: data['password']?.toString() ?? '',
            rol: data['rol']?.toString() ?? 'VENDEDOR',
          );
        }
      }
      onDataChanged();
    });
  }

  Future<void> subirProducto(int id, String nombre, double precio, int stock) async {
    if (!_initialized) return;
    try {
      await FirebaseFirestore.instance.collection('productos').doc(id.toString()).set({
        'id': id,
        'nombre': nombre,
        'precio_venta_unidad': precio,
        'stock_unidades': stock,
        'ultima_actualizacion': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> subirVenta({
    required int productoId,
    required String tipoVenta,
    required int cantidad,
    required double montoTotalCobrado,
    required double costoTotalAplicado,
    required double gananciaNeta,
    required String fecha,
  }) async {
    if (!_initialized) return;
    try {
      await FirebaseFirestore.instance.collection('ventas').add({
        'producto_id': productoId,
        'tipo_venta': tipoVenta,
        'cantidad': cantidad,
        'monto_total_cobrado': montoTotalCobrado,
        'costo_total_aplicado': costoTotalAplicado,
        'ganancia_neta': gananciaNeta,
        'fecha': fecha,
      });
    } catch (_) {}
  }

  Future<void> subirDeuda({
    required String cliente,
    required int productoId,
    required int cantidad,
    required double montoAdeudado,
    required double costoBase,
    required String estado,
    required String fecha,
  }) async {
    if (!_initialized) return;
    try {
      final docKey = "${cliente}_$productoId";
      await FirebaseFirestore.instance.collection('deudas').doc(docKey).set({
        'cliente_nombre': cliente,
        'producto_id': productoId,
        'cantidad': cantidad,
        'monto_adeudado': montoAdeudado,
        'costo_base': costoBase,
        'estado': estado,
        'fecha_creacion': fecha,
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> subirDatosYape({
    required String nombre,
    required String numero,
    required String base64Img,
  }) async {
    if (!_initialized) return;
    try {
      await FirebaseFirestore.instance
          .collection('configuracion_app')
          .doc('yape')
          .set({
        'yape_nombre': nombre,
        'yape_numero': numero,
        'yape_qr_base64': base64Img,
        'ultima_actualizacion': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> subirResumenGanancias({
    required String clave,
    required double montoTotal,
    required double gananciaTotal,
    required int unidadesTotales,
  }) async {
    if (!_initialized) return;
    try {
      await FirebaseFirestore.instance.collection('resumen_ganancias').doc(clave).set({
        'periodo_clave': clave,
        'monto_total': montoTotal,
        'ganancia_total': gananciaTotal,
        'unidades_totales': unidadesTotales,
        'ultima_actualizacion': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> subirUsuario(String usuario, String password, String rol) async {
    if (!_initialized) return;
    try {
      await FirebaseFirestore.instance.collection('usuarios').doc(usuario).set({
        'usuario': usuario,
        'password': password,
        'rol': rol,
        'ultima_actualizacion': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> borrarTodoEnNube() async {
    if (!_initialized) return;
    try {
      final batch = FirebaseFirestore.instance.batch();

      final prods = await FirebaseFirestore.instance.collection('productos').get();
      for (var d in prods.docs) {
        batch.delete(d.reference);
      }

      final vts = await FirebaseFirestore.instance.collection('ventas').get();
      for (var d in vts.docs) {
        batch.delete(d.reference);
      }

      final dds = await FirebaseFirestore.instance.collection('deudas').get();
      for (var d in dds.docs) {
        batch.delete(d.reference);
      }

      await batch.commit();
    } catch (_) {}
  }
}
