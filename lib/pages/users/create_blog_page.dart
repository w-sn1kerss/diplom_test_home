import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/blog_provider.dart';

class CreateBlogPage extends StatefulWidget {
  const CreateBlogPage({super.key});

  @override
  State<CreateBlogPage> createState() => _CreateBlogPageState();
}

class _CreateBlogPageState extends State<CreateBlogPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();

  File? _imageFile;
  bool _uploading = false;

  static const _accent = Color(0xFF6C63FF);

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final xfile =
    await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (xfile != null) setState(() => _imageFile = File(xfile.path));
  }

  Future<String?> _uploadImage() async {
    if (_imageFile == null) return null;

    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw Exception("Пользователь не авторизован");

    try {
      final ext = _imageFile!.path.split('.').last.toLowerCase();
      final fileName = '$userId/${DateTime.now().millisecondsSinceEpoch}.$ext';
      final bytes = await _imageFile!.readAsBytes();

      // Добавляем try-catch для обработки ошибок Storage
      await supabase.storage.from('blog-images').uploadBinary(
        fileName,
        bytes,
        fileOptions: FileOptions(contentType: 'image/$ext', upsert: true),
      );

      return fileName;
    } on StorageException catch (e) {
      // Supabase возвращает конкретные ошибки (например, доступ запрещен)
      throw Exception("Ошибка загрузки фото: ${e.message}");
    } catch (e) {
      // Любая другая ошибка (сеть, файл и т.д.)
      throw Exception("Не удалось загрузить изображение: $e");
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _uploading = true);

    try {
      // Если _uploadImage упадет, управление перейдет в блок catch
      final imageUrl = await _uploadImage();

      final ok = await context.read<BlogProvider>().createBlog(
        title: _titleCtrl.text.trim(),
        content: _contentCtrl.text.trim(),
        imageUrl: imageUrl,
      );

      if (!mounted) return;

      if (ok) {
        Navigator.pop(context);
      } else {
        throw Exception(context.read<BlogProvider>().error ?? 'Ошибка создания блога');
      }

    } catch (e) {
      // Вывод ошибки пользователю
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Новый блог'),
        actions: [
          TextButton(
            onPressed: _uploading ? null : _submit,
            child: _uploading
                ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Опубликовать',
                style: TextStyle(
                    color: _accent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Обложка
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDF0F4),
                    borderRadius: BorderRadius.circular(16),
                    image: _imageFile != null
                        ? DecorationImage(
                        image: FileImage(_imageFile!),
                        fit: BoxFit.cover)
                        : null,
                  ),
                  child: _imageFile == null
                      ? const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate_outlined,
                          size: 40, color: Colors.black38),
                      SizedBox(height: 8),
                      Text('Добавить обложку',
                          style: TextStyle(color: Colors.black38)),
                    ],
                  )
                      : null,
                ),
              ),
              const SizedBox(height: 20),

              // Заголовок
              TextFormField(
                controller: _titleCtrl,
                textInputAction: TextInputAction.next,
                validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Введите заголовок' : null,
                decoration: const InputDecoration(
                  hintText: 'Заголовок блога...',
                  labelText: 'Заголовок',
                ),
              ),
              const SizedBox(height: 16),

              // Контент
              TextFormField(
                controller: _contentCtrl,
                maxLines: 12,
                textInputAction: TextInputAction.newline,
                validator: (v) =>
                (v == null || v.trim().length < 10) ? 'Минимум 10 символов' : null,
                decoration: const InputDecoration(
                  hintText: 'Расскажите что-то интересное...',
                  labelText: 'Содержание',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}