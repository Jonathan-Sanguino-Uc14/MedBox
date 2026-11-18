import 'specialty_screen.dart';
import 'specialty_checkin.dart';

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data.dart';
import 'territory_screens.dart';
import 'theme.dart';

void notice(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
String friendlyError(Object error) {
  if (error is TimeoutException) {
    return 'La conexión tardó demasiado. Si usas una red escolar o pública, prueba con datos móviles u otra red Wi‑Fi.';
  }
  if (error is FormatException) return error.message;
  if (error is AuthException) {
    return 'No pudimos completar el acceso. Revisa tus datos, confirma tu correo e inténtalo de nuevo.';
  }
  if (error is PostgrestException) {
    return 'No fue posible consultar Med Box. La base de datos o tus permisos todavía pueden requerir configuración.';
  }
  return 'No pudimos conectar. Revisa tu conexión e inténtalo de nuevo.';
}

class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 620),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        children: children,
      ),
    ),
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.subtitle});
  final String text;
  final String? subtitle;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text, style: Theme.of(context).textTheme.titleLarge),
        if (subtitle != null)
          Text(subtitle!, style: const TextStyle(color: Color(0xFF526C79))),
      ],
    ),
  );
}

class Brand extends StatelessWidget {
  const Brand({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Med Box',
    image: true,
    child: SizedBox(
      width: 150,
      height: 38,
      child: ClipRect(
        child: OverflowBox(
          maxWidth: 220,
          maxHeight: 124,
          child: Image.asset(
            'assets/med_box_logo.png',
            width: 220,
            height: 124,
            excludeFromSemantics: true,
          ),
        ),
      ),
    ),
  );
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, this.client});
  final SupabaseClient? client;
  void enter(BuildContext context, bool demo) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => AccountGate(
        repository: CareRepository(demo: demo, client: client),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: PageBody(
        children: [
          const SizedBox(height: 24),
          const Align(alignment: Alignment.centerLeft, child: Brand()),
          const SizedBox(height: 38),
          Container(
            height: 215,
            decoration: BoxDecoration(
              color: MedColors.secondary.withValues(alpha: .16),
              borderRadius: BorderRadius.circular(36),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 155,
                  height: 155,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                const Icon(
                  Icons.health_and_safety_outlined,
                  size: 94,
                  color: MedColors.primary,
                ),
                Positioned(
                  right: 28,
                  top: 22,
                  child: _Bubble(Icons.favorite_rounded, MedColors.secondary),
                ),
                Positioned(
                  left: 30,
                  bottom: 24,
                  child: _Bubble(Icons.add_rounded, MedColors.accent),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          Text(
            'Tu salud,\nmejor acompañada.',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 12),
          const Text(
            'Un espacio para conectar con tus especialistas y cuidar de ti, paso a paso.',
            style: TextStyle(
              fontSize: 17,
              height: 1.6,
              color: Color(0xFF526C79),
            ),
          ),
          const SizedBox(height: 20),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(
                avatar: Icon(Icons.lock_outline, size: 16),
                label: Text('Sesiones privadas'),
              ),
              Chip(
                avatar: Icon(Icons.favorite_outline, size: 16),
                label: Text('4 especialidades'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: client == null
                ? null
                : () async {
                    if (client!.auth.currentUser != null) {
                      enter(context, false);
                      return;
                    }
                    final success = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => AuthScreen(client: client!),
                      ),
                    );
                    if (success == true && context.mounted) {
                      enter(context, false);
                    }
                  },
            child: Text(
              client?.auth.currentUser != null
                  ? 'Continuar con mi cuenta'
                  : 'Comenzar',
            ),
          ),
          TextButton(
            onPressed: () => enter(context, true),
            child: const Text('Explorar sin cuenta'),
          ),
          if (client == null)
            const Text(
              'Conexión no disponible. Puedes explorar la app y reiniciar para volver a conectar.',
            ),
          const SizedBox(height: 12),
          const Text(
            'Al explorar sin cuenta, la información no se guarda en la nube.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Color(0xFF526C79)),
          ),
        ],
      ),
    ),
  );
}

class _Bubble extends StatelessWidget {
  const _Bubble(this.icon, this.color);
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Icon(icon, color: MedColors.primary, size: 28),
  );
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.client});
  final SupabaseClient client;
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController(), password = TextEditingController();
  bool register = false, busy = false, obscure = true;
  String? error;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (register) {
        final result = await widget.client.auth.signUp(
          email: email.text.trim(),
          password: password.text,
          data: {'account_type': 'patient'},
        );
        if (!mounted) return;
        if (result.session == null) {
          notice(
            context,
            'Revisa tu correo para confirmar la cuenta. Después inicia sesión.',
          );
          setState(() => register = false);
        } else {
          Navigator.pop(context, true);
        }
      } else {
        await widget.client.auth.signInWithPassword(
          email: email.text.trim(),
          password: password.text,
        );
        if (mounted) Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Brand()),
    body: SafeArea(
      child: PageBody(
        children: [
          const SizedBox(height: 24),
          Text(
            register
                ? 'Tu acompañamiento\nempieza aquí.'
                : 'Qué bueno verte\nde nuevo.',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 12),
          const Text('Accede a tu espacio personal de Med Box.'),
          const SizedBox(height: 28),
          Form(
            key: form,
            child: Column(
              children: [
                TextFormField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(
                    labelText: 'Correo electrónico',
                    prefixIcon: Icon(Icons.mail_outline),
                  ),
                  validator: (v) =>
                      v != null &&
                          RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                              .hasMatch(v.trim())
                      ? null
                      : 'Escribe un correo válido.',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: password,
                  obscureText: obscure,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      tooltip: obscure
                          ? 'Mostrar contraseña'
                          : 'Ocultar contraseña',
                      onPressed: () => setState(() => obscure = !obscure),
                      icon: Icon(
                        obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: (v) => (v?.length ?? 0) >= 8
                      ? null
                      : 'Utiliza al menos 8 caracteres.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          FilledButton(
            onPressed: busy ? null : submit,
            child: Text(
              busy
                  ? 'Conectando…'
                  : register
                  ? 'Crear cuenta'
                  : 'Iniciar sesión',
            ),
          ),
          TextButton(
            onPressed: busy
                ? null
                : () => setState(() {
                    register = !register;
                    error = null;
                  }),
            child: Text(register ? 'Ya tengo una cuenta' : 'Crear una cuenta'),
          ),
          const Text(
            'Tu información se protege y solo la ve tu especialista.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

/// Routes provisioned specialists to their workspace; everyone else is a patient.
class AccountGate extends StatefulWidget {
  const AccountGate({super.key, required this.repository});
  final CareRepository repository;
  @override
  State<AccountGate> createState() => _AccountGateState();
}

class _AccountGateState extends State<AccountGate> {
  late Future<AccountRole> future = widget.repository.role();
  @override
  Widget build(BuildContext context) => FutureBuilder<AccountRole>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Scaffold(
          appBar: AppBar(title: const Brand()),
          body: PageBody(
            children: [
              const SectionTitle('No pudimos abrir tu cuenta'),
              Text(friendlyError(snapshot.error!)),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () =>
                    setState(() => future = widget.repository.role()),
                child: const Text('Volver a intentar'),
              ),
            ],
          ),
        );
      }
      if (!snapshot.hasData) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      final role = snapshot.data!;
      return role.isSpecialist || role.wantsProfessional
          ? ProfessionalAccountScreen(repository: widget.repository)
          : HomeShell(repository: widget.repository);
    },
  );
}

/// Professionals work from the web panel (apps/panel_web); the app is for patients.
class ProfessionalAccountScreen extends StatelessWidget {
  const ProfessionalAccountScreen({super.key, required this.repository});
  final CareRepository repository;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Brand()),
    body: PageBody(
      children: [
        const SizedBox(height: 24),
        const Icon(
          Icons.desktop_windows_outlined,
          size: 56,
          color: MedColors.primary,
        ),
        const SizedBox(height: 16),
        Text(
          'Esta es una cuenta profesional',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        const Text(
          'Los profesionales gestionan pacientes, asignan actividades de su especialidad y revisan su seguimiento desde el panel web de Med Box. La app móvil es para pacientes.',
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () async {
            await repository.client?.auth.signOut();
            if (context.mounted) Navigator.of(context).pop();
          },
          icon: const Icon(Icons.logout),
          label: const Text('Cerrar sesión'),
        ),
      ],
    ),
  );
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.repository});
  final CareRepository repository;
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int tab = 0;
  late Future<List<CareSession>> future;
  late Future<List<LinkRequest>> requests;
  @override
  void initState() {
    super.initState();
    refresh();
  }

  void refresh() {
    future = widget.repository.sessions();
    requests = widget.repository.myRequests();
  }

  void openSession(CareSession session) => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) =>
          SpecialtyScreen(session: session, repository: widget.repository),
    ),
  );
  Future<void> link() async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => LinkScreen(repository: widget.repository),
      ),
    );
    if (mounted) setState(refresh);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Brand(),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 20),
          child: CircleAvatar(
            backgroundColor: MedColors.secondary.withValues(alpha: .25),
            child: const Icon(Icons.person_outline, color: MedColors.primary),
          ),
        ),
      ],
    ),
    body: SafeArea(
      child: Column(
        children: [
          if (widget.repository.demo)
            Container(
              width: double.infinity,
              color: MedColors.secondary.withValues(alpha: .18),
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: const Text(
                'MODO EXPLORACIÓN · Lo que registres no se guarda',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: MedColors.primary),
              ),
            ),
          Expanded(
            child: tab == 2
                ? PreventionScreen(repository: widget.repository)
                : tab == 3
                ? settings()
                : FutureBuilder<List<CareSession>>(
                    future: future,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return PageBody(
                          children: [
                            const SectionTitle(
                              'No pudimos cargar tus sesiones',
                            ),
                            Text(friendlyError(snapshot.error!)),
                            const SizedBox(height: 20),
                            FilledButton(
                              onPressed: () => setState(refresh),
                              child: const Text('Volver a intentar'),
                            ),
                          ],
                        );
                      }
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      // Closed by the specialist: the record stays in the database for
                      // the patient's rights requests, but leaves the everyday feed.
                      final sessions = snapshot.data!
                          .where((session) => session.active)
                          .toList();
                      return RefreshIndicator(
                        onRefresh: () async {
                          setState(refresh);
                          await future;
                        },
                        child: PageBody(
                          children: [
                            Text(
                              tab == 0
                                  ? 'Hola, qué gusto verte'
                                  : 'Mis sesiones',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            Text(
                              tab == 0
                                  ? 'Hoy es un buen día para cuidar de ti.'
                                  : 'Tu acompañamiento en un solo lugar.',
                              style: const TextStyle(color: Color(0xFF526C79)),
                            ),
                            if (tab == 0) ...[
                              const SizedBox(height: 24),
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: MedColors.primary,
                                  borderRadius: BorderRadius.circular(28),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.favorite_border_rounded,
                                      color: MedColors.secondary,
                                      size: 30,
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'Pequeños pasos.\nUn mejor bienestar.',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 26,
                                        height: 1.2,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    const Text(
                                      'Conecta con tu especialista y continúa tu seguimiento.',
                                      style: TextStyle(
                                        color: Color(0xFFD3E4EA),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    FilledButton.icon(
                                      style: FilledButton.styleFrom(
                                        backgroundColor: MedColors.secondary,
                                        foregroundColor: MedColors.primary,
                                      ),
                                      onPressed: link,
                                      icon: const Icon(Icons.add_rounded),
                                      label: const Text(
                                        'Vincular con un código',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SectionTitle(
                                '¿Qué vamos a cuidar?',
                                subtitle: 'Encuentra tu especialidad',
                              ),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  return Wrap(
                                    spacing: 12,
                                    runSpacing: 12,
                                    children: Specialty.values.map((specialty) {
                                      return SizedBox(
                                        width: constraints.maxWidth < 300
                                            ? constraints.maxWidth
                                            : (constraints.maxWidth - 12) / 2,
                                        child: Card(
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(
                                              24,
                                            ),
                                            onTap: () {
                                              final matching = sessions.where(
                                                (item) =>
                                                    item.specialty == specialty,
                                              );
                                              if (matching.isNotEmpty) {
                                                openSession(matching.first);
                                              } else {
                                                link();
                                              }
                                            },
                                            child: Padding(
                                              padding: const EdgeInsets.all(18),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.all(
                                                          10,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: MedColors.secondary
                                                          .withValues(
                                                            alpha: .17,
                                                          ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            14,
                                                          ),
                                                    ),
                                                    child: Icon(
                                                      specialty.icon,
                                                      color: MedColors.primary,
                                                      size: 28,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 16),
                                                  Text(
                                                    specialty.label,
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .titleMedium,
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    specialty.subtitle,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Color(0xFF526C79),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  );
                                },
                              ),
                            ],
                            SectionTitle(
                              tab == 0
                                  ? 'Tu seguimiento'
                                  : 'Sesiones autorizadas',
                              subtitle:
                                  '${sessions.length} sesiones disponibles',
                            ),
                            if (sessions.isEmpty)
                              const Card(
                                child: Padding(
                                  padding: EdgeInsets.all(24),
                                  child: Text(
                                    'Aún no tienes sesiones. Solicita un código a tu especialista y espera su aprobación.',
                                  ),
                                ),
                              ),
                            for (final session in sessions)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Card(
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.all(16),
                                    leading: Icon(
                                      session.specialty.icon,
                                      color: MedColors.primary,
                                    ),
                                    title: Text(session.specialty.label),
                                    subtitle: Text(session.title),
                                    trailing: const Icon(Icons.chevron_right),
                                    onTap: () => openSession(session),
                                  ),
                                ),
                              ),
                            if (tab == 1)
                              FilledButton.icon(
                                onPressed: link,
                                icon: const Icon(Icons.add),
                                label: const Text('Vincular nueva sesión'),
                              ),
                            FutureBuilder<List<LinkRequest>>(
                              future: requests,
                              builder: (context, snap) {
                                final open = (snap.data ?? const [])
                                    .where((r) => r.status != 'approved')
                                    .toList();
                                if (open.isEmpty) {
                                  return const SizedBox.shrink();
                                }
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SectionTitle('Tus solicitudes'),
                                    for (final r in open)
                                      Card(
                                        child: ListTile(
                                          leading: Icon(r.specialty.icon),
                                          title: Text(r.specialty.label),
                                          subtitle: Text(
                                            requestStatusLabels[r.status] ??
                                                r.status,
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                            if (widget.repository.pendingCodes.isNotEmpty)
                              const Padding(
                                padding: EdgeInsets.only(top: 16),
                                child: Text(
                                  'Solicitud pendiente de aprobación de tu especialista.',
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: tab,
      onDestinationSelected: (value) => setState(() => tab = value),
      backgroundColor: Colors.white,
      indicatorColor: MedColors.secondary.withValues(alpha: .3),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: 'Inicio',
        ),
        NavigationDestination(
          icon: Icon(Icons.folder_outlined),
          label: 'Sesiones',
        ),
        NavigationDestination(
          icon: Icon(Icons.shield_outlined),
          label: 'Prevención',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          label: 'Mi cuenta',
        ),
      ],
    ),
  );
  Widget settings() => PageBody(
    children: [
      Text('Mi cuenta', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 20),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.verified_user_outlined,
                size: 36,
                color: MedColors.primary,
              ),
              const SizedBox(height: 16),
              Text(
                widget.repository.demo
                    ? 'Explorando sin cuenta'
                    : widget.repository.client?.auth.currentUser?.email ??
                          'Paciente',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Text(
                widget.repository.demo
                    ? 'Los registros se conservan mientras exploras. Al salir se descartan.'
                    : 'Tus registros se consultan mediante tu sesión de Supabase y las políticas de acceso de Med Box.',
              ),
            ],
          ),
        ),
      ),
      const SectionTitle('Tu privacidad'),
      const Text(
        'No solicitamos tu ubicación. Los registros de cada especialidad se comparten únicamente dentro de la sesión autorizada. Med Box no es un servicio de emergencias ni ofrece monitoreo continuo.',
      ),
      if (!widget.repository.demo) ...[
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final kind in const [
              ('export', 'Solicitar copia de mis datos'),
              ('delete', 'Solicitar eliminación'),
            ])
              OutlinedButton(
                onPressed: () async {
                  try {
                    await widget.repository.requestData(kind.$1);
                    if (mounted) {
                      notice(
                        context,
                        'Solicitud registrada. Se atenderá manualmente; no es inmediata.',
                      );
                    }
                  } catch (e) {
                    if (mounted) notice(context, friendlyError(e));
                  }
                },
                child: Text(kind.$2),
              ),
          ],
        ),
      ],
      const SizedBox(height: 24),
      OutlinedButton.icon(
        onPressed: () async {
          try {
            if (!widget.repository.demo) {
              await widget.repository.client!.auth.signOut();
            }
            if (mounted) Navigator.of(context).pop();
          } catch (e) {
            if (mounted) notice(context, friendlyError(e));
          }
        },
        icon: const Icon(Icons.logout),
        label: Text(
          widget.repository.demo ? 'Salir de la demostración' : 'Cerrar sesión',
        ),
      ),
      const SizedBox(height: 24),
      const Text(
        'Med Box 0.2\nFisioterapia · Dermatología · Oftalmología · Psicología',
        style: TextStyle(fontSize: 12),
      ),
    ],
  );
}

class LinkScreen extends StatefulWidget {
  const LinkScreen({super.key, required this.repository});
  final CareRepository repository;
  @override
  State<LinkScreen> createState() => _LinkScreenState();
}

class _LinkScreenState extends State<LinkScreen> {
  final code = TextEditingController();
  bool busy = false, sent = false;
  String? error;
  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (code.text.trim().isEmpty) {
      setState(() => error = 'Escribe el código de invitación.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.repository.requestLink(code.text);
      if (mounted) setState(() => sent = true);
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Vincular sesión')),
    body: PageBody(
      children: [
        const SizedBox(height: 30),
        Icon(
          sent ? Icons.mark_email_read_outlined : Icons.key_rounded,
          size: 64,
          color: MedColors.primary,
        ),
        const SizedBox(height: 24),
        Text(
          sent ? 'Solicitud enviada' : 'Conecta con tu especialista',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        Text(
          sent
              ? 'Tu especialista debe revisar y aprobar la solicitud. Podrás ver la sesión después de su aprobación.'
              : 'Introduce el código que te compartió tu especialista. El código inicia una solicitud; no concede acceso a información clínica.',
        ),
        const SizedBox(height: 24),
        if (!sent) ...[
          TextField(
            controller: code,
            textCapitalization: TextCapitalization.characters,
            maxLength: 64,
            decoration: const InputDecoration(
              labelText: 'Código de invitación',
            ),
          ),
          if (widget.repository.demo)
            const Text('Para explorar usa el código MEDBOX-DEMO'),
          if (error != null)
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: busy ? null : submit,
            child: Text(busy ? 'Enviando…' : 'Solicitar vinculación'),
          ),
        ] else
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Volver a mis sesiones'),
          ),
      ],
    ),
  );
}

class RecordScreen extends StatefulWidget {
  const RecordScreen({
    super.key,
    required this.session,
    required this.repository,
    this.activityId,
  });
  final CareSession session;
  final CareRepository repository;
  final String? activityId;
  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  final Map<String, dynamic> checkIn = {};
  final note = TextEditingController(), zone = TextEditingController();
  bool completed = false, consent = false, busy = false, imageConsent = false;
  double pain = 0;
  bool reportPain = false;
  String side = 'both';
  String? mood;
  Uint8List? image;
  String imageExtension = 'jpg';
  String? error;
  @override
  void dispose() {
    note.dispose();
    zone.dispose();
    super.dispose();
  }

  Future<void> pick() async {
    try {
      final file = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (file == null) return;
      if (await file.length() > 10 * 1024 * 1024) {
        throw const FormatException('Selecciona una imagen de menos de 10 MB.');
      }
      final bytes = await file.readAsBytes();
      final isPng =
          bytes.length > 4 &&
          bytes[0] == 0x89 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x4E &&
          bytes[3] == 0x47;
      final isJpeg = bytes.length > 3 && bytes[0] == 0xFF && bytes[1] == 0xD8;
      if (!isPng && !isJpeg) {
        throw const FormatException('Usa una imagen JPEG o PNG.');
      }
      if (mounted) {
        setState(() {
          image = bytes;
          imageExtension = isPng ? 'png' : 'jpg';
        });
      }
    } catch (e) {
      if (mounted) notice(context, friendlyError(e));
    }
  }

  Future<void> save() async {
    if (!consent) {
      setState(() => error = 'Confirma que deseas compartir este registro.');
      return;
    }
    if (image != null &&
        (zone.text.trim().isEmpty ||
            (checkIn['Identificador de lesión'] ?? '')
                .toString()
                .trim()
                .isEmpty)) {
      setState(
        () => error = 'Indica la zona corporal y el identificador de lesión para la fotografía.',
      );
      return;
    }
    if (image != null && !widget.repository.demo && !imageConsent) {
      setState(() => error = 'Autoriza el uso de la imagen o quítala.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    final draft = RecordDraft(
      completed: completed,
      pain: reportPain ? pain.round() : null,
      laterality: side,
      mood: mood,
      bodyZone: zone.text,
      note: note.text,
      image: widget.repository.demo ? null : image,
      imageExtension: imageExtension,
      activityId: widget.activityId,
      details: Map<String, dynamic>.from(checkIn),
    );
    try {
      await widget.repository.save(widget.session, draft);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.session.specialty.recordTitle)),
    body: PageBody(
      children: [
        Text(
          widget.session.specialty.subtitle,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text('Compartir con: ${widget.session.professional}'),
        const SizedBox(height: 20),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: completed,
          onChanged: (v) => setState(() => completed = v),
          title: Text(widget.session.specialty.completedLabel),
        ),
        if (widget.session.specialty == Specialty.physio) ...[
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: reportPain,
            onChanged: (v) => setState(() => reportPain = v),
            title: const Text('Agregar dolor reportado'),
          ),
          if (reportPain) ...[
            Text('Dolor reportado: ${pain.round()} de 10'),
            Slider(
              value: pain,
              max: 10,
              divisions: 10,
              label: '${pain.round()}',
              onChanged: (v) => setState(() => pain = v),
            ),
            const Text('0: sin dolor · 10: máximo dolor reportado'),
          ],
        ],
        if (widget.session.specialty == Specialty.skin) ...[
          const SizedBox(height: 16),
          TextField(
            controller: zone,
            maxLength: 100,
            decoration: const InputDecoration(
              labelText: 'Zona corporal (opcional)',
            ),
          ),
          ...[
            OutlinedButton.icon(
              onPressed: pick,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(
                widget.repository.demo
                    ? 'Vista previa de foto'
                    : 'Adjuntar foto',
              ),
            ),
            Text(
              widget.repository.demo
                  ? 'La imagen solo se previsualiza en este formulario. No se guarda ni se envía.'
                  : 'JPEG o PNG, máximo 10 MB. Se guarda en almacenamiento privado: solo tú y tu especialista de esta sesión pueden verla.',
              style: const TextStyle(fontSize: 12),
            ),
            if (image != null && !widget.repository.demo)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: imageConsent,
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: (v) => setState(() => imageConsent = v!),
                title: const Text(
                  'Autorizo guardar esta imagen para mi seguimiento.',
                ),
              ),
            if (image != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.memory(
                    image!,
                    height: 180,
                    fit: BoxFit.contain,
                    errorBuilder: (_, error, stack) =>
                        const Text('No se pudo mostrar esta imagen.'),
                  ),
                ),
              ),
          ],
        ],
        if (widget.session.specialty == Specialty.eyes) ...[
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: side,
            decoration: const InputDecoration(labelText: 'Ojo / lateralidad'),
            items: lateralityLabels.entries
                .map(
                  (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                )
                .toList(),
            onChanged: (v) => setState(() => side = v!),
          ),
          const SizedBox(height: 12),
          const Text(
            'Describe molestias o dudas. Este registro no mide tu visión ni sustituye un examen.',
          ),
        ],
        if (widget.session.specialty == Specialty.mind) ...[
          const SizedBox(height: 16),
          DropdownButtonFormField<String?>(
            initialValue: mood,
            decoration: const InputDecoration(
              labelText: '¿Cómo te sientes? (opcional)',
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Sin especificar'),
              ),
              ...moodLabels.entries.map(
                (e) => DropdownMenuItem<String?>(
                  value: e.key,
                  child: Text(e.value),
                ),
              ),
            ],
            onChanged: (v) => setState(() => mood = v),
          ),
          const SizedBox(height: 12),
          const Text(
            'Tu nota se comparte con el profesional de esta sesión. No es un diario privado ni un canal de atención inmediata.',
          ),
        ],
        SpecialtyCheckIn(
          specialty: widget.session.specialty,
          values: checkIn,
          onChanged: (key, value) => setState(() {
            if (value == null) {
              checkIn.remove(key);
            } else {
              checkIn[key] = value;
            }
          }),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: note,
          minLines: 3,
          maxLines: 5,
          maxLength: 2000,
          decoration: const InputDecoration(
            labelText: 'Tu nota (opcional)',
            alignLabelWithHint: true,
            hintText: '¿Cómo te fue hoy?',
          ),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: consent,
          controlAffinity: ListTileControlAffinity.leading,
          onChanged: (v) => setState(() => consent = v!),
          title: const Text(
            'Quiero compartir este registro con el profesional de esta sesión.',
          ),
        ),
        if (error != null)
          Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: busy ? null : save,
          child: Text(
            busy
                ? 'Guardando…'
                : widget.repository.demo
                ? 'Guardar registro'
                : 'Compartir registro',
          ),
        ),
      ],
    ),
  );
}

class EvidenceImage extends StatefulWidget {
  const EvidenceImage({
    super.key,
    required this.repository,
    required this.path,
  });
  final CareRepository repository;
  final String path;
  @override
  State<EvidenceImage> createState() => _EvidenceImageState();
}

class _EvidenceImageState extends State<EvidenceImage> {
  late final Future<Uint8List> bytes = widget.repository.evidence(widget.path);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: FutureBuilder<Uint8List>(
      future: bytes,
      builder: (context, snap) {
        if (snap.hasError) return const Text('Imagen no disponible.');
        if (!snap.hasData) return const LinearProgressIndicator();
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.memory(
            snap.data!,
            height: 180,
            fit: BoxFit.contain,
            semanticLabel: 'Foto del registro',
            errorBuilder: (_, e, s) => const Text('Imagen no disponible.'),
          ),
        );
      },
    ),
  );
}

class SkinPhotoComparison extends StatefulWidget {
  const SkinPhotoComparison({
    super.key,
    required this.records,
    required this.repository,
  });
  final List<CareRecord> records;
  final CareRepository repository;
  @override
  State<SkinPhotoComparison> createState() => _SkinPhotoComparisonState();
}

class _SkinPhotoComparisonState extends State<SkinPhotoComparison> {
  String? lesion;
  @override
  Widget build(BuildContext context) {
    final photos = widget.records
        .where(
          (r) =>
              r.evidencePath != null &&
              !r.hasVideo &&
              r.details['Identificador de lesión'] != null,
        )
        .toList();
    final ids = photos
        .map((r) => r.details['Identificador de lesión'].toString())
        .toSet()
        .toList();
    if (ids.isEmpty) return const SizedBox.shrink();
    final selected = ids.contains(lesion) ? lesion! : ids.first;
    final matching =
        photos
            .where(
              (r) =>
                  r.details['Identificador de lesión'].toString() == selected,
            )
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Comparación de evolución',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey(selected),
              initialValue: selected,
              decoration: const InputDecoration(labelText: 'Lesión'),
              items: ids
                  .map((id) => DropdownMenuItem(value: id, child: Text(id)))
                  .toList(),
              onChanged: (v) => setState(() => lesion = v),
            ),
            if (matching.length < 2)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'Agrega otra fotografía de esta lesión para comparar.',
                ),
              )
            else ...[
              const SizedBox(height: 12),
              const Text('Primera y última fotografía compartida'),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final r in [matching.first, matching.last])
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Column(
                          children: [
                            Text(
                              MaterialLocalizations.of(context)
                                  .formatMediumDate(r.date),
                            ),
                            EvidenceImage(
                              key: ValueKey(r.evidencePath),
                              repository: widget.repository,
                              path: r.evidencePath!,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const Text(
                'La iluminación y la distancia pueden cambiar la apariencia. Revisa la evolución con tu especialista.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
