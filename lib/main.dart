import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'dart:io';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cadastro com SQLite',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const CadastroPage(),
    );
  }
}

class CadastroPage extends StatefulWidget {
  const CadastroPage({super.key});

  @override
  State<CadastroPage> createState() => _CadastroPageState();
}

class _CadastroPageState extends State<CadastroPage> {
  final TextEditingController textoController = TextEditingController();
  final TextEditingController numeroController = TextEditingController();
  late final Future<Database> dbFuture;

  @override
  void initState() {
    super.initState();
    dbFuture = _abrirBancoExistente();
  }

  Future<Database> _abrirBancoExistente() async {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final path = join(exeDir, 'devTeste.db');

    return await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
          CREATE TABLE IF NOT EXISTS cadastro (
            numero INTEGER PRIMARY KEY CHECK (numero > 0),
            texto TEXT NOT NULL
          );
        ''');
          await db.execute('''
          CREATE TABLE IF NOT EXISTS log_operacoes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            operacao TEXT NOT NULL,
            data_hora TEXT DEFAULT (datetime('now', 'localtime')),
            numero INTEGER
          );
        ''');
          await db.execute('''
          CREATE TRIGGER log_insert AFTER INSERT ON cadastro
          BEGIN
            INSERT INTO log_operacoes (operacao, numero) VALUES ('INSERT', NEW.numero);
          END;
        ''');
          await db.execute('''
          CREATE TRIGGER log_update AFTER UPDATE ON cadastro
          BEGIN
            INSERT INTO log_operacoes (operacao, numero) VALUES ('UPDATE', NEW.numero);
          END;
        ''');
          await db.execute('''
          CREATE TRIGGER log_delete AFTER DELETE ON cadastro
          BEGIN
            INSERT INTO log_operacoes (operacao, numero) VALUES ('DELETE', OLD.numero);
          END;
        ''');
        },
      ),
    );
  }

  Future<void> salvar(BuildContext context) async {
    final texto = textoController.text.trim();
    final numero = int.tryParse(numeroController.text.trim());

    if (texto.isEmpty || numero == null || numero <= 0) {
      _mostrarMensagem(context, 'Preencha todos os campos corretamente.');
      return;
    }

    final db = await dbFuture;
    try {
      await db.insert('cadastro', {'numero': numero, 'texto': texto});
      _mostrarMensagem(context, 'Registro salvo!');
    } catch (e) {
      _mostrarMensagem(context, 'Erro ao salvar: número já existe.');
    }
  }

  Future<void> deletar(BuildContext context) async {
    final numero = int.tryParse(numeroController.text.trim());
    if (numero == null || numero <= 0) {
      _mostrarMensagem(context, 'Número inválido.');
      return;
    }

    final db = await dbFuture;
    final affectedRows = await db.delete(
      'cadastro',
      where: 'numero = ?',
      whereArgs: [numero],
    );
    _mostrarMensagem(
      context,
      affectedRows > 0 ? 'Registro deletado!' : 'Registro não encontrado.',
    );
  }

  Future<void> atualizar(BuildContext context) async {
    final texto = textoController.text.trim();
    final numero = int.tryParse(numeroController.text.trim());
    if (texto.isEmpty || numero == null || numero <= 0) {
      _mostrarMensagem(context, 'Preencha os campos corretamente.');
      return;
    }

    final db = await dbFuture;
    final affectedRows = await db.update(
      'cadastro',
      {'texto': texto},
      where: 'numero = ?',
      whereArgs: [numero],
    );
    _mostrarMensagem(
      context,
      affectedRows > 0 ? 'Registro atualizado!' : 'Registro não encontrado.',
    );
  }

  void _mostrarMensagem(BuildContext ctx, String msg) {
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    textoController.dispose();
    numeroController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cadastro SQLite')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: textoController,
              decoration: const InputDecoration(
                labelText: 'Texto',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: numeroController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Número',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => salvar(context),
                    icon: const Icon(Icons.save),
                    label: const Text('Salvar'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => deletar(context),
                    icon: const Icon(Icons.delete),
                    label: const Text('Deletar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => atualizar(context),
                    icon: const Icon(Icons.update),
                    label: const Text('Atualizar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
