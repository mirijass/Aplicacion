import 'package:flutter/material.dart';

/// Widget especializado para mostrar la imagen/logo de marcas de servicios
/// (Telcel, AT&T, Movistar, CFE, Aguakan, Amazon, Netflix, Cinepolis, etc.)
/// utilizando resolución inteligente de dominios y respaldos de marca atractivos.
class ServicioLogoWidget extends StatelessWidget {
  final String servicio;
  final double size;
  final double? iconSize;
  final BorderRadius? borderRadius;

  const ServicioLogoWidget({
    super.key,
    required this.servicio,
    this.size = 46,
    this.iconSize,
    this.borderRadius,
  });

  /// Resuelve el dominio web oficial para obtener el logo en alta calidad
  static String resolverDominio(String servicio) {
    final s = servicio.toLowerCase();

    // Recargas y Telefonía
    if (s.contains('telcel')) return 'telcel.com';
    if (s.contains('at&t') || s.contains('at-t') || s.contains('att')) return 'att.com.mx';
    if (s.contains('movistar')) return 'movistar.com.mx';
    if (s.contains('unefon')) return 'unefon.com.mx';
    if (s.contains('bait')) return 'mibait.com';
    if (s.contains('abib')) return 'abib.mx';
    if (s.contains('flash mobile')) return 'flashmobile.mx';
    if (s.contains('diri')) return 'diri.mx';
    if (s.contains('bigcel')) return 'bigcel.mx';
    if (s.contains('virgin')) return 'virginmobile.mx';
    if (s.contains('pillofon')) return 'pillofon.mx';
    if (s.contains('oxxo cel') || s.contains('oxxocel')) return 'oxxocel.com';
    if (s.contains('weex')) return 'weex.mx';
    if (s.contains('airalo')) return 'airalo.com';

    // Pagos de Servicios: Luz, Agua, Gas, Transporte
    if (s.contains('cfe')) return 'cfe.mx';
    if (s.contains('salamanca') || s.contains('cmapas')) return 'cmapas.gob.mx';
    if (s.contains('celaya') || s.contains('jumapa')) return 'jumapac.gob.mx';
    if (s.contains('omnibus')) return 'odm.com.mx';
    if (s.contains('aguakan')) return 'aguakan.com';
    if (s.contains('saltillo')) return 'aguasdesaltillo.com';
    if (s.contains('cea') || s.contains('queretaro')) return 'ceaqueretaro.gob.mx';
    if (s.contains('cespt') || s.contains('tijuana')) return 'cespt.gob.mx';
    if (s.contains('ciapacov') || s.contains('colima')) return 'ciapacov.gob.mx';
    if (s.contains('sacmex') || s.contains('agua')) return 'sacmex.cdmx.gob.mx';
    if (s.contains('naturgy') || s.contains('gas')) return 'naturgy.com.mx';
    if (s.contains('engie') || s.contains('maxigas')) return 'engie.com.mx';
    if (s.contains('compania mexicana de gas')) return 'cmg.com.mx';

    // TV, Internet, Telefonía fija
    if (s.contains('telmex')) return 'telmex.com';
    if (s.contains('totalplay')) return 'totalplay.com.mx';
    if (s.contains('izzi')) return 'izzi.mx';
    if (s.contains('megacable')) return 'megacable.com.mx';
    if (s.contains('dish')) return 'dish.com.mx';
    if (s.contains('sky')) return 'sky.com.mx';
    if (s.contains('axtel')) return 'axtelcorp.mx';

    // Peajes y Tags
    if (s.contains('easytrip')) return 'easytrip.com.mx';
    if (s.contains('pase')) return 'pase.com.mx';
    if (s.contains('televia')) return 'televia.com.mx';

    // Financiero y Venta por Catálogo
    if (s.contains('afore') || s.contains('banorte')) return 'xxi-banorte.com';
    if (s.contains('bbva')) return 'bbva.mx';
    if (s.contains('elektra')) return 'elektra.mx';
    if (s.contains('coppel')) return 'coppel.com';
    if (s.contains('arabela')) return 'arabela.com';
    if (s.contains('avon')) return 'avon.mx';
    if (s.contains('fuller')) return 'fuller.com.mx';
    if (s.contains('betterware')) return 'betterware.com.mx';

    // Tarjetas Digitales, Streaming, Gaming y Cine
    if (s.contains('amazon')) return 'amazon.com.mx';
    if (s.contains('netflix')) return 'netflix.com';
    if (s.contains('spotify')) return 'spotify.com';
    if (s.contains('playstation') || s.contains('psn')) return 'playstation.com';
    if (s.contains('xbox')) return 'xbox.com';
    if (s.contains('nintendo')) return 'nintendo.com';
    if (s.contains('cinepolis')) return 'cinepolis.com';
    if (s.contains('cinemex')) return 'cinemex.com';
    if (s.contains('inbursa') || s.contains('acuario')) return 'acuarioinbursa.com.mx';
    if (s.contains('crunchyroll')) return 'crunchyroll.com';
    if (s.contains('free fire')) return 'ff.garena.com';
    if (s.contains('fortnite')) return 'epicgames.com';
    if (s.contains('blizzard')) return 'blizzard.com';
    if (s.contains('bitdefender')) return 'bitdefender.com';
    if (s.contains('uber')) return 'uber.com';
    if (s.contains('google')) return 'play.google.com';
    if (s.contains('apple') || s.contains('itunes')) return 'apple.com';

    return 'gestopago.com';
  }

  /// URL de imagen de alta resolución desde la red de iconos
  static String obtenerUrlLogo(String servicio) {
    final dominio = resolverDominio(servicio);
    return 'https://t2.gstatic.com/faviconV2?client=SOCIAL&type=FAVICON&fallback_opts=TYPE,SIZE,URL&url=https://$dominio&size=128';
  }

  /// Colores representativos de la marca para respaldo visual
  static Color _obtenerColorMarca(String servicio) {
    final s = servicio.toLowerCase();
    if (s.contains('cfe')) return const Color(0xFF007A33);
    if (s.contains('telcel')) return const Color(0xFF002F6C);
    if (s.contains('at&t') || s.contains('att') || s.contains('at-t')) return const Color(0xFF00A8E0);
    if (s.contains('movistar')) return const Color(0xFF019DF4);
    if (s.contains('bait')) return const Color(0xFFE91E63);
    if (s.contains('netflix')) return const Color(0xFFE50914);
    if (s.contains('spotify')) return const Color(0xFF1DB954);
    if (s.contains('amazon')) return const Color(0xFF232F3E);
    if (s.contains('xbox')) return const Color(0xFF107C10);
    if (s.contains('playstation')) return const Color(0xFF003791);
    if (s.contains('nintendo')) return const Color(0xFFE60012);
    if (s.contains('cinepolis')) return const Color(0xFF0B2341);
    if (s.contains('cinemex')) return const Color(0xFFC61A23);
    if (s.contains('agua') || s.contains('aguakan') || s.contains('saltillo') || s.contains('cespt')) {
      return const Color(0xFF0288D1);
    }
    if (s.contains('gas') || s.contains('naturgy') || s.contains('engie')) {
      return const Color(0xFFEF6C00);
    }
    if (s.contains('free fire') || s.contains('fortnite') || s.contains('blizzard') || s.contains('crunchyroll')) {
      return const Color(0xFF673AB7);
    }
    if (s.contains('uber')) return const Color(0xFF000000);
    return const Color(0xFF2E7D32);
  }

  /// Ícono representativo para respaldo visual
  static IconData _obtenerIconoMarca(String servicio) {
    final s = servicio.toLowerCase();
    if (s.contains('cfe')) return Icons.electric_bolt_rounded;
    if (s.contains('agua') || s.contains('aguakan') || s.contains('saltillo') || s.contains('cea') || s.contains('cespt')) {
      return Icons.water_drop_rounded;
    }
    if (s.contains('gas') || s.contains('naturgy') || s.contains('engie')) {
      return Icons.local_fire_department_rounded;
    }
    if (s.contains('amazon')) return Icons.shopping_bag_rounded;
    if (s.contains('netflix') || s.contains('crunchyroll')) return Icons.movie_filter_rounded;
    if (s.contains('spotify')) return Icons.music_note_rounded;
    if (s.contains('playstation') || s.contains('xbox') || s.contains('nintendo') || s.contains('free fire') || s.contains('fortnite') || s.contains('blizzard')) {
      return Icons.sports_esports_rounded;
    }
    if (s.contains('cinepolis') || s.contains('cinemex') || s.contains('inbursa')) {
      return Icons.confirmation_number_rounded;
    }
    if (s.contains('easytrip') || s.contains('pase') || s.contains('televia')) {
      return Icons.directions_car_rounded;
    }
    if (s.contains('afore') || s.contains('bbva') || s.contains('elektra') || s.contains('coppel')) {
      return Icons.account_balance_rounded;
    }
    if (s.contains('telcel') || s.contains('att') || s.contains('at-t') || s.contains('movistar') || s.contains('unefon') || s.contains('bait') || s.contains('abib') || s.contains('diri') || s.contains('flash') || s.contains('bigcel')) {
      return Icons.phone_android_rounded;
    }
    return Icons.receipt_long_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final logoUrl = obtenerUrlLogo(servicio);
    final rad = borderRadius ?? BorderRadius.circular(12);
    final brandColor = _obtenerColorMarca(servicio);
    final brandIcon = _obtenerIconoMarca(servicio);
    final iSize = iconSize ?? (size * 0.52);

    Widget fallbackWidget = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: brandColor.withAlpha(30),
        borderRadius: rad,
        border: Border.all(color: brandColor.withAlpha(64), width: 1.2),
      ),
      child: Center(
        child: Icon(
          brandIcon,
          color: brandColor,
          size: iSize,
        ),
      ),
    );

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: rad,
        border: Border.all(color: const Color(0x2E9E9E9E), width: 1),
      ),
      child: ClipRRect(
        borderRadius: rad,
        child: Padding(
          padding: EdgeInsets.all(size * 0.12),
          child: Image.network(
            logoUrl,
            width: size,
            height: size,
            cacheWidth: 96,
            fit: BoxFit.contain,
            headers: const {'User-Agent': 'Mozilla/5.0'},
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: Icon(
                  brandIcon,
                  color: brandColor.withAlpha(150),
                  size: iSize * 0.85,
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return fallbackWidget;
            },
          ),
        ),
      ),
    );
  }
}
