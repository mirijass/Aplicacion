import 'package:flutter/material.dart';
import '../models/producto_model.dart';
import '../models/usuario_model.dart';
import '../controllers/producto_controller.dart';
import '../utils/app_theme.dart';
import 'widgets/custom_text_field.dart';

/// Formulario modal para registrar o editar un producto (Admin y Editor)
class ProductoFormDialog extends StatefulWidget {
  final Producto? producto;
  final ProductoController productoController;
  final Usuario? usuarioLogeado;

  const ProductoFormDialog({
    super.key,
    this.producto,
    required this.productoController,
    this.usuarioLogeado,
  });

  static Future<void> show(
    BuildContext context,
    ProductoController controller, {
    Producto? producto,
    Usuario? usuarioLogeado,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ProductoFormDialog(
        producto: producto,
        productoController: controller,
        usuarioLogeado: usuarioLogeado,
      ),
    );
  }

  @override
  State<ProductoFormDialog> createState() => _ProductoFormDialogState();
}

class _ProductoFormDialogState extends State<ProductoFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nombreCtrl;
  late TextEditingController _precioCtrl;
  late TextEditingController _stockCtrl;
  late TextEditingController _imagenCtrl;

  bool get _esEdicion => widget.producto != null;

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController(text: widget.producto?.nombre ?? '');
    _precioCtrl = TextEditingController(text: widget.producto?.precio.toString() ?? '');
    _stockCtrl = TextEditingController(text: widget.producto?.cantidad.toString() ?? '100');
    _imagenCtrl = TextEditingController(text: widget.producto?.imagen ?? '');
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _precioCtrl.dispose();
    _stockCtrl.dispose();
    _imagenCtrl.dispose();
    super.dispose();
  }

  void _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    final nombre = _nombreCtrl.text.trim();
    final precio = double.tryParse(_precioCtrl.text.trim()) ?? 0.0;
    final stock = int.tryParse(_stockCtrl.text.trim()) ?? 0;
    final imagen = _imagenCtrl.text.trim();

    final prod = Producto(
      id: widget.producto?.id,
      nombre: nombre,
      precio: precio,
      cantidad: stock,
      imagen: imagen,
    );

    bool ok = false;
    if (_esEdicion) {
      ok = await widget.productoController.actualizarProducto(
        prod,
        usuarioLogeado: widget.usuarioLogeado,
      );
    } else {
      ok = await widget.productoController.crearProducto(
        prod,
        usuarioLogeado: widget.usuarioLogeado,
      );
    }

    if (!mounted) return;

    if (ok) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.productoController.successMessage ?? 'Operación exitosa',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.productoController.errorMessage ?? 'Error al guardar',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 24,
        right: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Text(
                _esEdicion ? 'Editar Producto' : 'Registrar Nuevo Producto',
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textMain,
                ),
              ),
              const SizedBox(height: 18),

              // Nombre del Producto
              CustomTextField(
                controller: _nombreCtrl,
                label: 'Nombre del Producto *',
                hint: 'ej. Camisa de Algodón, Mochila...',
                prefixIcon: Icons.shopping_bag_outlined,
                maxLength: 36,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Ingresa el nombre del producto';
                  }
                  if (val.trim().length < 3) {
                    return 'Debe tener al menos 3 caracteres';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Precio y Stock en una fila
              Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      controller: _precioCtrl,
                      label: 'Precio (\$ MXN) *',
                      hint: 'ej. 299.99',
                      prefixIcon: Icons.attach_money_rounded,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Ingresa el precio';
                        }
                        final p = double.tryParse(val.trim());
                        if (p == null || p <= 0) {
                          return 'Precio inválido';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CustomTextField(
                      controller: _stockCtrl,
                      label: 'Stock (Cantidad) *',
                      hint: 'ej. 100',
                      prefixIcon: Icons.inventory_2_outlined,
                      keyboardType: TextInputType.number,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Ingresa el stock';
                        }
                        final s = int.tryParse(val.trim());
                        if (s == null || s < 0) {
                          return 'Stock inválido';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // URL de Imagen
              CustomTextField(
                controller: _imagenCtrl,
                label: 'URL de Imagen (Opcional)',
                hint: 'ej. https://fakestoreapi.com/img/...',
                prefixIcon: Icons.image_outlined,
              ),
              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: Icon(_esEdicion ? Icons.save_rounded : Icons.add_rounded, size: 18),
                      label: Text(_esEdicion ? 'Guardar' : 'Agregar'),
                      onPressed: _submitForm,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
