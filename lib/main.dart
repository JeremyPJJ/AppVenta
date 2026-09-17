import 'package:flutter/material.dart';
import 'database/db_helper.dart';

final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier(ThemeMode.dark);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, currentMode, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Control de Ventas',
          themeMode: currentMode,
          theme: ThemeData(
            useMaterial3: true,
            colorSchemeSeed: Colors.indigo,
            brightness: Brightness.light,
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF0B101D),
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF3B82F6),
              surface: Color(0xFF11182D),
              onSurface: Colors.white,
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF0B101D),
              elevation: 0,
              centerTitle: false,
            ),
            cardTheme: CardThemeData(
              color: const Color(0xFF11182D),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFF1E293B), width: 1),
              ),
            ),
            navigationBarTheme: const NavigationBarThemeData(
              backgroundColor: Color(0xFF0A0F1D),
              indicatorColor: Color(0xFF2563EB),
            ),
          ),
          home: const PantallaPrincipal(),
        );
      },
    );
  }
}

class MiniSparklinePainter extends CustomPainter {
  final Color color;
  MiniSparklinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    path.moveTo(0, size.height * 0.8);
    path.cubicTo(
      size.width * 0.35, size.height * 0.4,
      size.width * 0.65, size.height * 0.8,
      size.width, size.height * 0.1,
    );

    // Relleno degradado suave debajo de la curva
    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          color.withValues(alpha: 0.25),
          color.withValues(alpha: 0.0),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(fillPath, fillPaint);

    // Línea de la curva
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class PantallaPrincipal extends StatefulWidget {
  const PantallaPrincipal({super.key});

  @override
  State<PantallaPrincipal> createState() => _PantallaPrincipalState();
}

class _PantallaPrincipalState extends State<PantallaPrincipal> {
  int _pestanaActual = 0;
  final dbHelper = DatabaseHelper.instance;

  String _filtroPeriodo = 'Hoy';
  DateTime? _fechaFiltroSeleccionada;
  int? _mesFiltroSeleccionado;
  int? _anioFiltroSeleccionado;

  final List<String> _nombresMeses = const [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
  ];

  @override
  Widget build(BuildContext context) {
    final bool esModoOscuro = themeModeNotifier.value == ThemeMode.dark;

    final List<Widget> pantallas = [
      _vistaDashboard(),
      _vistaVender(),
      _vistaProductos(),
      _vistaDeudas(),
    ];

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 70,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF6366F1)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.bar_chart, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: esModoOscuro ? Colors.white : Colors.black87,
                    ),
                    children: const [
                      TextSpan(text: 'Administrador de '),
                      TextSpan(
                        text: 'Ventas',
                        style: TextStyle(color: Color(0xFF60A5FA)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: esModoOscuro ? const Color(0xFF1E293B) : Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.settings, size: 22),
              tooltip: 'Configuración',
              onPressed: _modalConfiguracion,
            ),
          ),
        ],
      ),
      body: pantallas[_pestanaActual],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _pestanaActual,
        onDestinationSelected: (index) => setState(() => _pestanaActual = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_customize), label: 'Ganancias'),
          NavigationDestination(icon: Icon(Icons.point_of_sale), label: 'Vender'),
          NavigationDestination(icon: Icon(Icons.inventory_2), label: 'Productos'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Deudas'),
        ],
      ),
    );
  }

  // --- CONFIGURACIÓN Y MODO OSCURO ---
  void _modalConfiguracion() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final bool esOscuro = themeModeNotifier.value == ThemeMode.dark;

          return AlertDialog(
            title: Row(
              children: const [
                Icon(Icons.settings, color: Colors.indigo),
                SizedBox(width: 8),
                Expanded(child: Text('Configuración')),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    secondary: Icon(
                      esOscuro ? Icons.dark_mode : Icons.light_mode,
                      color: esOscuro ? Colors.amber : Colors.indigo,
                    ),
                    title: const Text('Modo Oscuro', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(esOscuro ? 'Activado' : 'Desactivado'),
                    value: esOscuro,
                    onChanged: (val) {
                      setModalState(() {
                        themeModeNotifier.value = val ? ThemeMode.dark : ThemeMode.light;
                      });
                      setState(() {});
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.delete_forever, color: Colors.red),
                    title: const Text('Borrar todos los datos', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    subtitle: const Text('Restablecer productos, ventas y deudas'),
                    onTap: _modalConfirmarBorrarTodo,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cerrar'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _modalConfirmarBorrarTodo() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                '¿Eliminar todos los datos?',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: const Text(
          'Esta acción borrará permanentemente TODOS los productos, ventas, métricas y deudas registradas.\n\n¿Estás seguro de que deseas restablecer la aplicación para volver a ingresar datos desde cero?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final nav = Navigator.of(ctx);
              final messenger = ScaffoldMessenger.of(context);
              await dbHelper.borrarTodosLosDatos();
              nav.pop();
              if (mounted) {
                Navigator.of(context).pop();
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Se han eliminado todos los datos correctamente'),
                    backgroundColor: Colors.red,
                  ),
                );
                setState(() {});
              }
            },
            child: const Text('Sí, Eliminar Todo'),
          ),
        ],
      ),
    );
  }

  // --- 1. PESTAÑA DASHBOARD (GANANCIAS, GRÁFICOS Y TOP VENDIDOS) ---
  Widget _vistaDashboard() {
    final bool esModoOscuro = themeModeNotifier.value == ThemeMode.dark;

    return FutureBuilder<Map<String, dynamic>>(
      future: dbHelper.obtenerMetricasDashboard(
        mesFiltro: _filtroPeriodo == 'Mes Específico' ? _mesFiltroSeleccionado : null,
        anioFiltro: _filtroPeriodo == 'Mes Específico' ? _anioFiltroSeleccionado : null,
        fechaFiltro: _filtroPeriodo == 'Fecha Específica' ? _fechaFiltroSeleccionada : null,
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final data = snapshot.data!;

        String labelBotonFiltro = _filtroPeriodo;
        if (_filtroPeriodo == 'Fecha Específica' && _fechaFiltroSeleccionada != null) {
          labelBotonFiltro = "${_fechaFiltroSeleccionada!.day}/${_fechaFiltroSeleccionada!.month}/${_fechaFiltroSeleccionada!.year}";
        } else if (_filtroPeriodo == 'Mes Específico' && _mesFiltroSeleccionado != null && _anioFiltroSeleccionado != null) {
          labelBotonFiltro = "${_nombresMeses[_mesFiltroSeleccionado! - 1]} $_anioFiltroSeleccionado";
        }

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            // Subtítulo descriptivo y Botón de Filtro de Periodo
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Controla tus ventas, analiza tus resultados\ny haz crecer tu negocio.',
                    style: TextStyle(
                      fontSize: 12,
                      color: esModoOscuro ? Colors.grey.shade400 : Colors.grey.shade700,
                      height: 1.3,
                    ),
                  ),
                ),
                InkWell(
                  onTap: _seleccionarFiltroPeriodo,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: esModoOscuro ? const Color(0xFF1E293B) : Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: esModoOscuro ? const Color(0xFF334155) : Colors.indigo.shade200,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: esModoOscuro ? const Color(0xFF60A5FA) : Colors.indigo,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$labelBotonFiltro ∨',
                          style: TextStyle(
                            fontSize: 12,
                            color: esModoOscuro ? Colors.white : Colors.indigo.shade900,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Resumen de Métricas KPI
            _seccionMetricasKPINeon(data),
            const SizedBox(height: 20),

            // Gráfico de Ganancias Semanales
            _seccionGraficoVentasNeon(),
            const SizedBox(height: 20),

            // Ranking de Productos Más Vendidos
            _seccionProductosMasVendidos(),
          ],
        );
      },
    );
  }

  void _seleccionarFiltroPeriodo() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Seleccionar Periodo de Ganancias',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.today, color: Colors.teal),
                title: const Text('Hoy'),
                trailing: _filtroPeriodo == 'Hoy' ? const Icon(Icons.check, color: Colors.teal) : null,
                onTap: () {
                  setState(() {
                    _filtroPeriodo = 'Hoy';
                    _fechaFiltroSeleccionada = null;
                    _mesFiltroSeleccionado = null;
                  });
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.date_range, color: Colors.green),
                title: const Text('Esta Semana (Últimos 7 días)'),
                trailing: _filtroPeriodo == 'Esta Semana' ? const Icon(Icons.check, color: Colors.green) : null,
                onTap: () {
                  setState(() {
                    _filtroPeriodo = 'Esta Semana';
                    _fechaFiltroSeleccionada = null;
                    _mesFiltroSeleccionado = null;
                  });
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.calendar_month, color: Colors.indigo),
                title: const Text('Este Mes (Mes Actual)'),
                trailing: _filtroPeriodo == 'Este Mes' ? const Icon(Icons.check, color: Colors.indigo) : null,
                onTap: () {
                  setState(() {
                    _filtroPeriodo = 'Este Mes';
                    _fechaFiltroSeleccionada = null;
                    _mesFiltroSeleccionado = null;
                  });
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.event_note, color: Color(0xFF8B5CF6)),
                title: const Text('Elegir Mes Específico...'),
                subtitle: const Text('Ver ganancias de cualquier mes del año'),
                trailing: _filtroPeriodo == 'Mes Específico' ? const Icon(Icons.check, color: Color(0xFF8B5CF6)) : null,
                onTap: () {
                  Navigator.pop(ctx);
                  _dialogElegirMesEspecifico();
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit_calendar, color: Colors.orange),
                title: const Text('Elegir Fecha Específica...'),
                subtitle: const Text('Ver ganancias de un día en particular'),
                trailing: _filtroPeriodo == 'Fecha Específica' ? const Icon(Icons.check, color: Colors.orange) : null,
                onTap: () async {
                  Navigator.pop(ctx);
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setState(() {
                      _filtroPeriodo = 'Fecha Específica';
                      _fechaFiltroSeleccionada = picked;
                      _mesFiltroSeleccionado = null;
                    });
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _dialogElegirMesEspecifico() {
    final DateTime hoy = DateTime.now();
    final int anioActual = hoy.year;
    final int mesActual = hoy.month;

    int anio = _anioFiltroSeleccionado ?? anioActual;
    if (anio > anioActual) anio = anioActual;

    int mes = _mesFiltroSeleccionado ?? mesActual;
    if (anio == anioActual && mes > mesActual) {
      mes = mesActual;
    }

    final List<int> listaAnios = List.generate(
      (anioActual + 10) - 2020 + 1,
      (index) => 2020 + index,
    );

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final int maxMesPermitido = (anio >= anioActual) ? mesActual : 12;
          final int mesValido = mes > maxMesPermitido ? maxMesPermitido : mes;

          return AlertDialog(
            title: Row(
              children: const [
                Icon(Icons.calendar_month, color: Color(0xFF8B5CF6)),
                SizedBox(width: 8),
                Expanded(child: Text('Seleccionar Mes')),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Elige el mes y año para consultar:', style: TextStyle(fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: mesValido,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Mes', border: OutlineInputBorder()),
                        items: List.generate(maxMesPermitido, (i) {
                          return DropdownMenuItem<int>(
                            value: i + 1,
                            child: Text(_nombresMeses[i]),
                          );
                        }),
                        onChanged: (val) {
                          if (val != null) setModalState(() => mes = val);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 110,
                      child: DropdownButtonFormField<int>(
                        initialValue: anio,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Año', border: OutlineInputBorder()),
                        items: listaAnios.map((y) {
                          final bool esFuturo = y > anioActual;
                          return DropdownMenuItem<int>(
                            value: y,
                            enabled: !esFuturo,
                            child: Text(
                              y.toString(),
                              style: TextStyle(
                                color: esFuturo ? Colors.grey : null,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null && val <= anioActual) {
                            setModalState(() {
                              anio = val;
                              if (anio == anioActual && mes > mesActual) {
                                mes = mesActual;
                              }
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6), foregroundColor: Colors.white),
                onPressed: () {
                  setState(() {
                    _filtroPeriodo = 'Mes Específico';
                    _mesFiltroSeleccionado = mes;
                    _anioFiltroSeleccionado = anio;
                  });
                  Navigator.pop(ctx);
                },
                child: const Text('Aplicar Mes'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _seccionMetricasKPINeon(Map<String, dynamic> data) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.12,
      children: [
        _tarjetaKPINeon(
          titulo: (_filtroPeriodo == 'Fecha Específica' && _fechaFiltroSeleccionada != null)
              ? 'Ventas del ${_fechaFiltroSeleccionada!.day}/${_fechaFiltroSeleccionada!.month}/${_fechaFiltroSeleccionada!.year}'
              : 'Ventas de Hoy',
          valor: 'S/ ${(data['ventas_hoy'] as num?)?.toDouble().toStringAsFixed(2) ?? "0.00"}',
          icono: Icons.calendar_today,
          colorAccento: const Color(0xFF3B82F6),
          colorFondo: const Color(0xFF101B33),
          colorBorde: const Color(0xFF1E40AF),
          comparativa: '0% vs. día anterior',
        ),
        _tarjetaKPINeon(
          titulo: 'Ganancia Semanal',
          valor: 'S/ ${(data['ganancia_semana'] as num?)?.toDouble().toStringAsFixed(2) ?? "0.00"}',
          icono: Icons.trending_up,
          colorAccento: const Color(0xFF10B981),
          colorFondo: const Color(0xFF0C241E),
          colorBorde: const Color(0xFF065F46),
          comparativa: '0% vs. semana pasada',
        ),
        _tarjetaKPINeon(
          titulo: (_filtroPeriodo == 'Mes Específico' && _mesFiltroSeleccionado != null)
              ? 'Ganancia (${_nombresMeses[_mesFiltroSeleccionado! - 1]})'
              : 'Ganancia Mensual',
          valor: 'S/ ${(data['ganancia_mes'] as num?)?.toDouble().toStringAsFixed(2) ?? "0.00"}',
          icono: Icons.calendar_month,
          colorAccento: const Color(0xFF8B5CF6),
          colorFondo: const Color(0xFF1B1333),
          colorBorde: const Color(0xFF5B21B6),
          comparativa: '0% vs. mes pasado',
        ),
        _tarjetaKPINeon(
          titulo: 'Total Fiado (Por Cobrar)',
          valor: 'S/ ${(data['por_cobrar'] as num?)?.toDouble().toStringAsFixed(2) ?? "0.00"}',
          icono: Icons.person,
          colorAccento: const Color(0xFFF59E0B),
          colorFondo: const Color(0xFF26190E),
          colorBorde: const Color(0xFF9A3412),
          comparativa: '0% vs. semana pasada',
        ),
      ],
    );
  }

  Widget _tarjetaKPINeon({
    required String titulo,
    required String valor,
    required IconData icono,
    required Color colorAccento,
    required Color colorFondo,
    required Color colorBorde,
    required String comparativa,
  }) {
    final bool esModoOscuro = themeModeNotifier.value == ThemeMode.dark;

    return Container(
      decoration: BoxDecoration(
        color: esModoOscuro ? colorFondo : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: esModoOscuro ? colorBorde : colorAccento.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: esModoOscuro
            ? [
                BoxShadow(
                  color: colorAccento.withValues(alpha: 0.12),
                  blurRadius: 10,
                  spreadRadius: 1,
                )
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                )
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Onda ubicada a la derecha para NO cruzarse con el texto de la izquierda
            Positioned(
              right: 0,
              bottom: 0,
              width: 75,
              height: 42,
              child: CustomPaint(
                painter: MiniSparklinePainter(color: colorAccento),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: colorAccento.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icono, size: 18, color: colorAccento),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          titulo,
                          style: TextStyle(
                            fontSize: 12,
                            color: esModoOscuro ? Colors.grey.shade300 : Colors.grey.shade800,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    valor,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: esModoOscuro ? Colors.white : Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      Icon(
                        Icons.north_east,
                        size: 11,
                        color: esModoOscuro ? const Color(0xFF10B981) : Colors.green.shade800,
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          comparativa,
                          style: TextStyle(
                            fontSize: 10,
                            color: esModoOscuro ? const Color(0xFF10B981) : Colors.green.shade800,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _seccionGraficoVentasNeon() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: dbHelper.obtenerVentasPorDiaSemana(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        final ventasPorDia = snapshot.data!;
        final bool esModoOscuro = themeModeNotifier.value == ThemeMode.dark;

        double maxGanancia = 100.0;
        for (var v in ventasPorDia) {
          final g = (v['ganancia_total'] as num).toDouble();
          if (g > maxGanancia) maxGanancia = g;
        }

        final ahora = DateTime.now();
        final List<Map<String, dynamic>> diasSemana = List.generate(7, (i) {
          final fecha = ahora.subtract(Duration(days: 6 - i));
          final fechaStr = "${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}";
          final match = ventasPorDia.firstWhere(
            (v) => v['fecha_dia'] == fechaStr,
            orElse: () => {'ganancia_total': 0.0},
          );

          return {
            'dia': _obtenerNombreDia(fecha.weekday),
            'ganancia': (match['ganancia_total'] as num).toDouble(),
          };
        });

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: esModoOscuro ? const Color(0xFF11182D) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: esModoOscuro ? const Color(0xFF1E293B) : Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.bar_chart, color: Color(0xFF60A5FA), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Ganancias de los últimos 7 días',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Evolución de tus ganancias.',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Stack(
                children: [
                  Column(
                    children: List.generate(5, (index) {
                      final double valY = maxGanancia * (4 - index) / 4;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 22),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 45,
                              child: Text(
                                'S/ ${valY.toStringAsFixed(0)}',
                                style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                              ),
                            ),
                            Expanded(
                              child: Container(
                                height: 1,
                                color: esModoOscuro ? const Color(0xFF1E293B) : Colors.grey.shade200,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                  Positioned.fill(
                    left: 50,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: diasSemana.map((d) {
                        final double ganancia = d['ganancia'] as double;
                        final double porcentaje = (ganancia / maxGanancia).clamp(0.08, 1.0);

                        return Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              'S/ ${ganancia.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: esModoOscuro ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              width: 28,
                              height: 90 * porcentaje,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF2563EB), Color(0xFF60A5FA)],
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                ),
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF3B82F6).withValues(alpha: 0.4),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(d['dia'].toString(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.grey)),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _obtenerNombreDia(int weekday) {
    switch (weekday) {
      case 1: return 'Lun';
      case 2: return 'Mar';
      case 3: return 'Mié';
      case 4: return 'Jue';
      case 5: return 'Vie';
      case 6: return 'Sáb';
      case 7: return 'Dom';
      default: return '';
    }
  }

  Widget _seccionProductosMasVendidos() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: dbHelper.obtenerProductosMasVendidos(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        final masVendidos = snapshot.data!;
        final bool esModoOscuro = themeModeNotifier.value == ThemeMode.dark;

        if (masVendidos.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: esModoOscuro ? const Color(0xFF151C35) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: esModoOscuro ? const Color(0xFF232D52) : Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.assignment, color: Color(0xFF818CF8), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('Aún no hay ventas registradas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      SizedBox(height: 2),
                      Text('para calcular los productos más vendidos.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
          );
        }

        int maxUnidades = 1;
        if (masVendidos.isNotEmpty) {
          maxUnidades = (masVendidos.first['total_unidades'] as num).toInt();
          if (maxUnidades <= 0) maxUnidades = 1;
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: esModoOscuro ? const Color(0xFF11182D) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: esModoOscuro ? const Color(0xFF1E293B) : Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('🏆 Productos Más Vendidos', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Icon(Icons.star, color: Colors.amber),
                ],
              ),
              const SizedBox(height: 12),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: masVendidos.length,
                separatorBuilder: (context, index) => const Divider(height: 16),
                itemBuilder: (context, i) {
                  final item = masVendidos[i];
                  final String nombre = item['producto_nombre'].toString();
                  final int units = (item['total_unidades'] as num).toInt();
                  final double totalVendido = (item['total_ventas'] as num).toDouble();
                  final double porcentaje = (units / maxUnidades).clamp(0.0, 1.0);

                  final medallas = ['🥇', '🥈', '🥉', '4️⃣', '5️⃣'];
                  final medalla = i < medallas.length ? medallas[i] : '#${i + 1}';

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(medalla, style: const TextStyle(fontSize: 18)),
                              const SizedBox(width: 8),
                              Text(nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            ],
                          ),
                          Text(
                            '$units u. vendidas | S/ ${totalVendido.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF60A5FA), fontSize: 13),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      LinearProgressIndicator(
                        value: porcentaje,
                        backgroundColor: esModoOscuro ? Colors.grey.shade800 : Colors.grey.shade200,
                        color: i == 0 ? Colors.amber.shade600 : const Color(0xFF3B82F6),
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // --- 2. PESTAÑA VENDER (INDIVIDUAL Y MÚLTIPLE) ---
  Widget _vistaVender() {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.shopping_cart_checkout),
        label: const Text('Venta Múltiple'),
        onPressed: _modalVentaMultiple,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: dbHelper.obtenerProductos(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final productos = snapshot.data!;
          if (productos.isEmpty) {
            return const Center(
              child: Text(
                'No hay productos registrados.\nAgrega un producto en la pestaña "Productos".',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
            itemCount: productos.length,
            itemBuilder: (context, i) {
              final p = productos[i];
              final int stock = p['stock_unidades'] as int? ?? 0;
              final double precioUnidad = (p['precio_venta_unidad'] as num?)?.toDouble() ?? 0.0;

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: stock > 0 ? const Color(0xFF1E3A8A) : Colors.red.shade900,
                    child: Icon(
                      stock > 0 ? Icons.shopping_bag : Icons.remove_shopping_cart,
                      color: stock > 0 ? const Color(0xFF60A5FA) : Colors.redAccent,
                    ),
                  ),
                  title: Text(
                    p['nombre'].toString(),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  subtitle: Text(
                    'Precio: S/ ${precioUnidad.toStringAsFixed(2)} c/u\nStock disponible: $stock u.',
                  ),
                  isThreeLine: true,
                  trailing: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.add_shopping_cart, size: 18),
                    label: const Text('Vender'),
                    onPressed: () => _modalVenderPorUnidad(p),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _modalVentaMultiple() async {
    final productos = await dbHelper.obtenerProductos();
    if (!mounted) return;

    if (productos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay productos registrados para vender.')),
      );
      return;
    }

    final List<Map<String, dynamic>> carrito = [];
    int? productoSeleccionadoId = productos.first['id'] as int;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final bool esModoOscuro = themeModeNotifier.value == ThemeMode.dark;

          final prodActual = productos.firstWhere(
            (p) => p['id'] == productoSeleccionadoId,
            orElse: () => productos.first,
          );

          double totalGeneral = 0.0;
          int totalItems = 0;
          final List<Map<String, dynamic>> itemsAVender = [];

          for (var item in carrito) {
            final int id = item['producto_id'] as int;
            final int cant = item['cantidad'] as int;
            final double precioUnit = (item['precio_unit'] as num).toDouble();
            final double costoUnit = (item['costo_unit'] as num).toDouble();

            final double subtotal = cant * precioUnit;
            final double costoAplicado = cant * costoUnit;
            final double ganancia = subtotal - costoAplicado;

            totalGeneral += subtotal;
            totalItems += cant;
            itemsAVender.add({
              'producto_id': id,
              'cantidad': cant,
              'monto_total_cobrado': subtotal,
              'costo_total_aplicado': costoAplicado,
              'ganancia_neta': ganancia,
            });
          }

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Container(
              padding: const EdgeInsets.all(16),
              constraints: const BoxConstraints(maxHeight: 580, maxWidth: 450),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.shopping_cart_checkout, color: Color(0xFF60A5FA)),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Venta Múltiple',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Select / Dropdown de Producto (Sin texto de stock)
                  DropdownButtonFormField<int>(
                    initialValue: productoSeleccionadoId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Selecciona Producto',
                      prefixIcon: Icon(Icons.inventory_2),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: productos.map((p) {
                      final double precio = (p['precio_venta_unidad'] as num).toDouble();
                      return DropdownMenuItem<int>(
                        value: p['id'] as int,
                        child: Text(
                          '${p['nombre']} - S/ ${precio.toStringAsFixed(2)}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() {
                          productoSeleccionadoId = val;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 10),

                  // Botón Agregar a Venta (Ancho completo)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.add_shopping_cart, size: 18),
                      label: const Text('Agregar a Venta', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () {
                        final id = prodActual['id'] as int;
                        final String nombre = prodActual['nombre'].toString();
                        final double precioUnit = (prodActual['precio_venta_unidad'] as num).toDouble();
                        final double costoUnit = (prodActual['costo_unitario'] as num?)?.toDouble() ?? 0.0;

                        setModalState(() {
                          final indexExistente = carrito.indexWhere((item) => item['producto_id'] == id);
                          if (indexExistente >= 0) {
                            carrito[indexExistente]['cantidad'] = (carrito[indexExistente]['cantidad'] as int) + 1;
                          } else {
                            carrito.add({
                              'producto_id': id,
                              'nombre': nombre,
                              'precio_unit': precioUnit,
                              'costo_unit': costoUnit,
                              'cantidad': 1,
                            });
                          }
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Lista / Carrito de productos agregados con botones +/-
                  const Text(
                    '📋 Productos agregados:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: carrito.isEmpty
                        ? Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: esModoOscuro ? const Color(0xFF1E293B) : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'Aún no has agregado productos.\nSelecciona uno arriba y toca "Agregar".',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey, fontSize: 13),
                            ),
                          )
                        : ListView.separated(
                            itemCount: carrito.length,
                            separatorBuilder: (context, index) => const Divider(height: 8),
                            itemBuilder: (context, i) {
                              final item = carrito[i];
                              final String nombre = item['nombre'].toString();
                              final int cant = item['cantidad'] as int;
                              final double precioUnit = (item['precio_unit'] as num).toDouble();
                              final double subtotal = cant * precioUnit;

                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: esModoOscuro ? const Color(0xFF1E293B) : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            nombre,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'S/ ${subtotal.toStringAsFixed(2)} (S/ ${precioUnit.toStringAsFixed(2)} c/u)',
                                            style: const TextStyle(fontSize: 12, color: Color(0xFF60A5FA), fontWeight: FontWeight.w600),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Botones + / - para aumentar o disminuir cantidad
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        InkWell(
                                          onTap: () {
                                            setModalState(() {
                                              if (cant > 1) {
                                                carrito[i]['cantidad'] = cant - 1;
                                              } else {
                                                carrito.removeAt(i);
                                              }
                                            });
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: Colors.red.withValues(alpha: 0.2),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(Icons.remove, size: 16, color: Colors.redAccent),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 8),
                                          child: Text(
                                            '$cant',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                          ),
                                        ),
                                        InkWell(
                                          onTap: () {
                                            setModalState(() {
                                              carrito[i]['cantidad'] = cant + 1;
                                            });
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: Colors.green.withValues(alpha: 0.2),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(Icons.add, size: 16, color: Colors.greenAccent),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                          tooltip: 'Eliminar producto',
                                          onPressed: () {
                                            setModalState(() {
                                              carrito.removeAt(i);
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 12),

                  // Resumen y Confirmar
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: esModoOscuro ? const Color(0xFF101B33) : Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: esModoOscuro ? const Color(0xFF1E40AF) : Colors.indigo.shade200),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Unidades: $totalItems u.',
                                style: TextStyle(fontSize: 11, color: esModoOscuro ? Colors.grey.shade300 : Colors.grey.shade800),
                              ),
                              Text(
                                'S/ ${totalGeneral.toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF3B82F6)),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text('Confirmar Venta', style: TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: itemsAVender.isEmpty
                              ? null
                              : () async {
                                  final nav = Navigator.of(ctx);
                                  final messenger = ScaffoldMessenger.of(context);
                                  await dbHelper.registrarVentaMultiple(itemsAVender);
                                  nav.pop();
                                  if (mounted) {
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text('Venta múltiple realizada por S/ ${totalGeneral.toStringAsFixed(2)} ($totalItems unidades)'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                    setState(() {});
                                  }
                                },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _modalVenderPorUnidad(Map<String, dynamic> prod) {
    final cantidadCtrl = TextEditingController(text: '1');
    final double precioUnidad = (prod['precio_venta_unidad'] as num?)?.toDouble() ?? 0.0;
    final int stockDisponible = prod['stock_unidades'] as int? ?? 0;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final int cantidad = int.tryParse(cantidadCtrl.text) ?? 1;
          final double total = cantidad * precioUnidad;

          return AlertDialog(
            title: Text('Vender por unidad: ${prod['nombre']}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Stock disponible: $stockDisponible u.',
                  style: TextStyle(
                    color: stockDisponible <= 0 ? Colors.redAccent : Colors.grey.shade400,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (stockDisponible <= 0)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      'Aviso: El stock actual es negativo o cero. Se registrará la venta de todos modos.',
                      style: TextStyle(color: Colors.redAccent, fontSize: 12),
                    ),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: cantidadCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Cantidad de unidades',
                    border: OutlineInputBorder(),
                    suffixText: 'unidades',
                  ),
                  onChanged: (val) => setModalState(() {}),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total a Cobrar:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        'S/ ${total.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF60A5FA),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                ),
                onPressed: cantidad <= 0
                    ? null
                    : () async {
                        final nav = Navigator.of(ctx);
                        final messenger = ScaffoldMessenger.of(context);
                        await dbHelper.registrarVentaDirecta(
                          productoId: prod['id'] as int,
                          tipoVenta: 'UNIDAD',
                          cantidad: cantidad,
                        );
                        nav.pop();
                        if (mounted) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('Venta de $cantidad unidad(es) realizada'),
                              backgroundColor: Colors.green,
                            ),
                          );
                          setState(() {});
                        }
                      },
                child: const Text('Confirmar Venta'),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- 3. PESTAÑA PRODUCTOS (LISTADO, EDICIÓN Y REGISTRO) ---
  Widget _vistaProductos() {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _modalAgregarProducto,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo Producto'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: dbHelper.obtenerProductos(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final productos = snapshot.data!;
          if (productos.isEmpty) return const Center(child: Text('No hay productos registrados'));

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: productos.length,
            itemBuilder: (context, i) {
              final p = productos[i];
              final int stock = p['stock_unidades'] as int? ?? 0;
              final double precioUnidad = (p['precio_venta_unidad'] as num?)?.toDouble() ?? 0.0;

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  title: Text(p['nombre'].toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    'Stock: $stock u.\nPrecio Unidad: S/ ${precioUnidad.toStringAsFixed(2)}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit, color: Color(0xFF60A5FA)),
                    tooltip: 'Editar producto',
                    onPressed: () => _modalEditarProducto(p),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // --- 4. PESTAÑA DEUDAS ---
  Widget _vistaDeudas() {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.orange.shade800,
        foregroundColor: Colors.white,
        onPressed: _modalAgregarDeuda,
        icon: const Icon(Icons.person_add),
        label: const Text('Nueva Deuda'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: dbHelper.obtenerClientesDeudores(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final clientes = snapshot.data!;
          if (clientes.isEmpty) {
            return const Center(
              child: Text(
                'No hay deudas pendientes.\nUsa "Nueva Deuda" para registrar una.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: clientes.length,
            itemBuilder: (context, i) {
              final c = clientes[i];
              final String clienteNombre = c['cliente_nombre'].toString();
              final double totalDeuda = (c['total_deuda'] as num?)?.toDouble() ?? 0.0;

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  onTap: () => _modalDetalleDeuda(clienteNombre),
                  leading: const CircleAvatar(
                    backgroundColor: Colors.orange,
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  title: Text(
                    clienteNombre,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  subtitle: Text(
                    'Debe: S/ ${totalDeuda.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orangeAccent),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton.filled(
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.remove, size: 20),
                        tooltip: 'Restar Deuda',
                        onPressed: () => _modalRestarDeuda(clienteNombre, totalDeuda),
                      ),
                      const SizedBox(width: 4),
                      IconButton.filled(
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.orange.shade700,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.add, size: 20),
                        tooltip: 'Aumentar Deuda',
                        onPressed: () => _modalAumentarDeuda(clienteNombre),
                      ),
                      const SizedBox(width: 6),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => _modalCobrarDeuda(clienteNombre, totalDeuda),
                        child: const Text('Cobrar'),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // --- MODALES Y DIÁLOGOS ---

  void _modalDetalleDeuda(String clienteNombre) {
    showDialog(
      context: context,
      builder: (ctx) => FutureBuilder<List<Map<String, dynamic>>>(
        future: dbHelper.obtenerDetalleDeudasCliente(clienteNombre),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const AlertDialog(content: SizedBox(height: 100, child: Center(child: CircularProgressIndicator())));
          }
          final items = snapshot.data!;
          final bool esModoOscuro = themeModeNotifier.value == ThemeMode.dark;

          double totalDeuda = 0.0;
          for (var item in items) {
            totalDeuda += (item['monto_adeudado'] as num).toDouble();
          }

          return AlertDialog(
            title: Row(
              children: [
                const CircleAvatar(backgroundColor: Colors.orange, child: Icon(Icons.person, color: Colors.white)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(clienteNombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('📋 Productos adeudados:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 10),
                  Table(
                    border: TableBorder.all(
                      color: esModoOscuro ? Colors.grey.shade700 : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    columnWidths: const {
                      0: FlexColumnWidth(2),
                      1: FlexColumnWidth(1),
                      2: FlexColumnWidth(1.5),
                    },
                    children: [
                      TableRow(
                        decoration: BoxDecoration(
                          color: esModoOscuro ? const Color(0xFF1E293B) : Colors.indigo.shade50,
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(
                              'Producto',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: esModoOscuro ? Colors.white : Colors.indigo.shade900,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(
                              'Cant.',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: esModoOscuro ? Colors.white : Colors.indigo.shade900,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(
                              'Subtotal',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: esModoOscuro ? Colors.white : Colors.indigo.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      ...items.map((item) {
                        final double subtotal = (item['monto_adeudado'] as num).toDouble();
                        return TableRow(
                          children: [
                            Padding(padding: const EdgeInsets.all(8), child: Text(item['producto_nombre'].toString())),
                            Padding(padding: const EdgeInsets.all(8), child: Text('${item['cantidad']} u.')),
                            Padding(padding: const EdgeInsets.all(8), child: Text('S/ ${subtotal.toStringAsFixed(2)}')),
                          ],
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: esModoOscuro ? const Color(0xFF26190E) : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: esModoOscuro ? const Color(0xFF9A3412) : Colors.orange.shade300),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Pendiente:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: esModoOscuro ? Colors.white : Colors.orange.shade900,
                          ),
                        ),
                        Text(
                          'S/ ${totalDeuda.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: esModoOscuro ? Colors.orangeAccent : Colors.orange.shade900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cerrar'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _modalRestarDeuda(String clienteNombre, double montoTotalDeuda) async {
    final itemsDeuda = await dbHelper.obtenerDetalleDeudasCliente(clienteNombre);
    if (!mounted) return;

    if (itemsDeuda.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este cliente no tiene deudas pendientes')),
      );
      return;
    }

    int itemIdSeleccionado = itemsDeuda.first['id'] as int;
    final unidadesCtrl = TextEditingController(text: '1');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final bool esModoOscuro = themeModeNotifier.value == ThemeMode.dark;

          final itemActual = itemsDeuda.firstWhere(
            (item) => item['id'] == itemIdSeleccionado,
            orElse: () => itemsDeuda.first,
          );

          final int cantidadAdeudadaItem = (itemActual['cantidad'] as num).toInt();
          final double montoItemActual = (itemActual['monto_adeudado'] as num).toDouble();
          final double precioUnit = cantidadAdeudadaItem > 0 ? (montoItemActual / cantidadAdeudadaItem) : 0.0;

          final int unidadesARestar = int.tryParse(unidadesCtrl.text) ?? 1;
          final int unidadesAjustadas = unidadesARestar.clamp(1, cantidadAdeudadaItem > 0 ? cantidadAdeudadaItem : 1);
          final double montoDescuento = unidadesAjustadas * precioUnit;
          final int unidadesRestantes = (cantidadAdeudadaItem - unidadesAjustadas).clamp(0, cantidadAdeudadaItem);

          return AlertDialog(
            title: Text('Restar deuda a: $clienteNombre'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: itemIdSeleccionado,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Selecciona Producto',
                      prefixIcon: Icon(Icons.inventory_2),
                      border: OutlineInputBorder(),
                    ),
                    items: itemsDeuda.map((item) {
                      final double m = (item['monto_adeudado'] as num).toDouble();
                      final int c = (item['cantidad'] as num).toInt();
                      return DropdownMenuItem<int>(
                        value: item['id'] as int,
                        child: Text('${item['producto_nombre']} ($c u. - S/ ${m.toStringAsFixed(2)})'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() {
                          itemIdSeleccionado = val;
                          unidadesCtrl.text = '1';
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Adeudado actual: $cantidadAdeudadaItem u. (S/ ${montoItemActual.toStringAsFixed(2)})',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: esModoOscuro ? Colors.orangeAccent : Colors.orange.shade900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: unidadesCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '¿Cuántas unidades restar?',
                      hintText: '1',
                      border: OutlineInputBorder(),
                      helperText: 'Ingresa las unidades que el cliente está cancelando',
                    ),
                    onChanged: (val) => setModalState(() {}),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: esModoOscuro ? const Color(0xFF1E293B) : Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: esModoOscuro ? const Color(0xFF334155) : Colors.indigo.shade200),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Monto a descontar:', style: TextStyle(color: esModoOscuro ? Colors.grey.shade300 : Colors.grey.shade800)),
                            Text('- S/ ${montoDescuento.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Unidades que quedarán:', style: TextStyle(color: esModoOscuro ? Colors.grey.shade300 : Colors.grey.shade800)),
                            Text('$unidadesRestantes u.', style: TextStyle(fontWeight: FontWeight.bold, color: esModoOscuro ? Colors.white : Colors.indigo.shade900)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
                onPressed: (unidadesARestar <= 0)
                    ? null
                    : () async {
                        final nav = Navigator.of(ctx);
                        final messenger = ScaffoldMessenger.of(context);
                        await dbHelper.restarDeudaItem(
                          deudaId: itemIdSeleccionado,
                          montoARestar: montoDescuento,
                        );
                        nav.pop();
                        if (mounted) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('Se restaron $unidadesAjustadas u. (S/ ${montoDescuento.toStringAsFixed(2)}) de ${itemActual['producto_nombre']}'),
                              backgroundColor: Colors.red.shade700,
                            ),
                          );
                          setState(() {});
                        }
                      },
                child: const Text('Restar Deuda'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _modalEditarProducto(Map<String, dynamic> prod) {
    final nombreCtrl = TextEditingController(text: prod['nombre'].toString());
    final precioUnidadCtrl = TextEditingController(text: prod['precio_venta_unidad'].toString());
    final stockCtrl = TextEditingController(text: prod['stock_unidades'].toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Editar Producto: ${prod['nombre']}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreCtrl,
                decoration: const InputDecoration(labelText: 'Nombre del producto', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: precioUnidadCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Precio de venta (S/)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: stockCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Unidades en stock (Stock actual)',
                  border: OutlineInputBorder(),
                  helperText: 'Puedes ajustar el stock disponible aquí',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
            onPressed: () async {
              final nav = Navigator.of(ctx);
              final messenger = ScaffoldMessenger.of(context);
              await dbHelper.editarProducto(
                id: prod['id'] as int,
                nombre: nombreCtrl.text.trim(),
                precioVentaUnidad: double.tryParse(precioUnidadCtrl.text) ?? 0.0,
                stockUnidades: int.tryParse(stockCtrl.text) ?? 0,
              );
              nav.pop();
              if (mounted) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('Producto actualizado correctamente'), backgroundColor: Colors.green),
                );
                setState(() {});
              }
            },
            child: const Text('Guardar Cambios'),
          ),
        ],
      ),
    );
  }

  void _modalAumentarDeuda(String clienteNombre) async {
    final productos = await dbHelper.obtenerProductos();
    if (!mounted) return;

    if (productos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay productos disponibles')),
      );
      return;
    }

    final cantidadCtrl = TextEditingController(text: '1');
    int productoSeleccionadoId = productos.first['id'] as int;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final bool esModoOscuro = themeModeNotifier.value == ThemeMode.dark;
          final prodActual = productos.firstWhere(
            (p) => p['id'] == productoSeleccionadoId,
            orElse: () => productos.first,
          );
          final double precioUnit = (prodActual['precio_venta_unidad'] as num?)?.toDouble() ?? 0.0;
          final int cantidad = int.tryParse(cantidadCtrl.text) ?? 1;
          final double montoAdicional = cantidad * precioUnit;

          return AlertDialog(
            title: Text('Aumentar deuda a: $clienteNombre'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: productoSeleccionadoId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Producto adicional',
                      prefixIcon: Icon(Icons.inventory_2),
                      border: OutlineInputBorder(),
                    ),
                    items: productos.map((p) {
                      return DropdownMenuItem<int>(
                        value: p['id'] as int,
                        child: Text(p['nombre'].toString()),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setModalState(() => productoSeleccionadoId = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: cantidadCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Cantidad a agregar (Unidades)',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) => setModalState(() {}),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: esModoOscuro ? const Color(0xFF26190E) : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: esModoOscuro ? const Color(0xFF9A3412) : Colors.orange.shade300),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Monto adicional:', style: TextStyle(fontWeight: FontWeight.bold, color: esModoOscuro ? Colors.white : Colors.orange.shade900)),
                        Text(
                          '+ S/ ${montoAdicional.toStringAsFixed(2)}',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: esModoOscuro ? Colors.orangeAccent : Colors.orange.shade900),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800, foregroundColor: Colors.white),
                onPressed: () async {
                  final nav = Navigator.of(ctx);
                  final messenger = ScaffoldMessenger.of(context);
                  await dbHelper.aumentarDeudaCliente(
                    clienteNombre: clienteNombre,
                    productoId: productoSeleccionadoId,
                    tipoVenta: 'UNIDAD',
                    cantidad: cantidad,
                  );
                  nav.pop();
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Deuda de $clienteNombre incrementada'),
                        backgroundColor: Colors.orange.shade800,
                      ),
                    );
                    setState(() {});
                  }
                },
                child: const Text('Aumentar Deuda'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _modalCobrarDeuda(String clienteNombre, double montoTotalDeuda) {
    bool esCobroTotal = true;
    final abonoCtrl = TextEditingController(text: montoTotalDeuda.toStringAsFixed(2));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final bool esModoOscuro = themeModeNotifier.value == ThemeMode.dark;
          final double montoAbonado = double.tryParse(abonoCtrl.text) ?? 0.0;
          final double saldoRestante = (montoTotalDeuda - montoAbonado).clamp(0.0, montoTotalDeuda);

          return AlertDialog(
            title: Text('Cobrar a: $clienteNombre'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Deuda pendiente: S/ ${montoTotalDeuda.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orangeAccent),
                  ),
                  const SizedBox(height: 16),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment<bool>(
                        value: true,
                        label: Text('Cobrar Todo'),
                        icon: Icon(Icons.done_all),
                      ),
                      ButtonSegment<bool>(
                        value: false,
                        label: Text('Abonar Parcial'),
                        icon: Icon(Icons.payments),
                      ),
                    ],
                    selected: {esCobroTotal},
                    onSelectionChanged: (Set<bool> selection) {
                      setModalState(() {
                        esCobroTotal = selection.first;
                        if (esCobroTotal) {
                          abonoCtrl.text = montoTotalDeuda.toStringAsFixed(2);
                        }
                      });
                    },
                  ),
                  if (!esCobroTotal) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: abonoCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Monto a Abonar (S/)',
                        border: OutlineInputBorder(),
                        prefixText: 'S/ ',
                      ),
                      onChanged: (val) => setModalState(() {}),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: esModoOscuro ? const Color(0xFF1E293B) : Colors.indigo.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: esModoOscuro ? const Color(0xFF334155) : Colors.indigo.shade200),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Saldo restante que quedará:',
                            style: TextStyle(
                              color: esModoOscuro ? Colors.grey.shade300 : Colors.grey.shade800,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'S/ ${saldoRestante.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: esModoOscuro ? const Color(0xFF60A5FA) : Colors.indigo.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                onPressed: () async {
                  final nav = Navigator.of(ctx);
                  final messenger = ScaffoldMessenger.of(context);

                  if (esCobroTotal || montoAbonado >= montoTotalDeuda) {
                    await dbHelper.saldarDeudasCliente(clienteNombre);
                  } else if (montoAbonado > 0) {
                    await dbHelper.saldarDeudasClienteParcial(clienteNombre, montoAbonado);
                  } else {
                    messenger.showSnackBar(const SnackBar(content: Text('Ingresa un monto válido para abonar')));
                    return;
                  }

                  nav.pop();
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          esCobroTotal || montoAbonado >= montoTotalDeuda
                              ? 'Deuda de $clienteNombre cobrada por completo'
                              : 'Abono de S/ ${montoAbonado.toStringAsFixed(2)} registrado para $clienteNombre',
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                    setState(() {});
                  }
                },
                child: const Text('Confirmar Cobro'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _modalAgregarDeuda() async {
    final productos = await dbHelper.obtenerProductos();
    if (!mounted) return;

    if (productos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Primero registra productos en la pestaña "Productos"')),
      );
      return;
    }

    final clienteCtrl = TextEditingController();
    final cantidadCtrl = TextEditingController(text: '1');
    int productoSeleccionadoId = productos.first['id'] as int;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final bool esModoOscuro = themeModeNotifier.value == ThemeMode.dark;
          final prodActual = productos.firstWhere(
            (p) => p['id'] == productoSeleccionadoId,
            orElse: () => productos.first,
          );
          final double precioUnit = (prodActual['precio_venta_unidad'] as num?)?.toDouble() ?? 0.0;
          final int cantidad = int.tryParse(cantidadCtrl.text) ?? 1;
          final double totalDeuda = cantidad * precioUnit;

          return AlertDialog(
            title: const Text('Registrar Deuda (Fiado)'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: clienteCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del cliente / deudor',
                      hintText: 'Ej: Juan Pérez',
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: productoSeleccionadoId,
                    decoration: const InputDecoration(
                      labelText: 'Producto',
                      prefixIcon: Icon(Icons.inventory_2),
                      border: OutlineInputBorder(),
                    ),
                    items: productos.map((p) {
                      return DropdownMenuItem<int>(
                        value: p['id'] as int,
                        child: Text(p['nombre'].toString()),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setModalState(() => productoSeleccionadoId = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: cantidadCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '¿Cuántas unidades?',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) => setModalState(() {}),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: esModoOscuro ? const Color(0xFF26190E) : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: esModoOscuro ? const Color(0xFF9A3412) : Colors.orange.shade300),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total Deuda:', style: TextStyle(fontWeight: FontWeight.bold, color: esModoOscuro ? Colors.white : Colors.orange.shade900)),
                        Text(
                          'S/ ${totalDeuda.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: esModoOscuro ? Colors.orangeAccent : Colors.orange.shade900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade800,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  if (clienteCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Por favor ingresa el nombre de la persona')),
                    );
                    return;
                  }
                  final nav = Navigator.of(ctx);
                  final messenger = ScaffoldMessenger.of(context);
                  await dbHelper.registrarDeuda(
                    cliente: clienteCtrl.text.trim(),
                    productoId: productoSeleccionadoId,
                    tipoVenta: 'UNIDAD',
                    cantidad: cantidad,
                  );
                  nav.pop();
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Deuda registrada a ${clienteCtrl.text.trim()}'),
                        backgroundColor: Colors.orange.shade800,
                      ),
                    );
                    setState(() {});
                  }
                },
                child: const Text('Guardar Deuda'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _modalAgregarProducto() {
    final nombreCtrl = TextEditingController();
    final precioUnidadCtrl = TextEditingController();
    final stockInicialCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nuevo Producto'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'Nombre del producto', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: precioUnidadCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Precio de venta (S/)',
                  hintText: 'Ej: 3.50',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: stockInicialCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Unidades en stock (Stock inicial)',
                  hintText: '0',
                  border: OutlineInputBorder(),
                  helperText: 'Ingresa la cantidad de unidades en inventario',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
            onPressed: () async {
              if (nombreCtrl.text.trim().isEmpty) return;
              final nav = Navigator.of(ctx);
              await dbHelper.agregarProducto(
                nombre: nombreCtrl.text.trim(),
                precioVentaUnidad: double.tryParse(precioUnidadCtrl.text) ?? 0.0,
                stockInicialUnidades: int.tryParse(stockInicialCtrl.text) ?? 0,
              );
              nav.pop();
              if (mounted) setState(() {});
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}