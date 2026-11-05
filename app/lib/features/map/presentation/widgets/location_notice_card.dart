import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../map_location_view_model.dart';

/// Aviso sobre GPS/permissão exibido sobre o mapa.
class LocationNoticeCard extends StatelessWidget {
  const LocationNoticeCard({
    super.key,
    required this.status,
    required this.onOpenLocationSettings,
    required this.onRequestPermission,
    required this.onOpenAppSettings,
    required this.onRetry,
  });

  final MapLocationStatus status;
  final VoidCallback onOpenLocationSettings;
  final VoidCallback onRequestPermission;
  final VoidCallback onOpenAppSettings;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final notice = _noticeFor(status);
    if (notice == null) {
      return const SizedBox.shrink();
    }

    return Material(
      color: Colors.white,
      elevation: 12,
      shadowColor: const Color(0x242E3C3E),
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: notice.isError
                        ? AppColors.dangerSurface
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    notice.icon,
                    size: 22,
                    color: notice.isError
                        ? AppColors.danger
                        : AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notice.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        notice.message,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (notice.actionLabel != null) ...[
              const SizedBox(height: 14),
              FilledButton.tonal(
                onPressed: notice.onAction,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.surface,
                  foregroundColor: AppColors.primary,
                  minimumSize: const Size.fromHeight(44),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(notice.actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }

  _NoticeContent? _noticeFor(MapLocationStatus status) {
    return switch (status) {
      MapLocationStatus.noGpsHardware => _NoticeContent(
        icon: Icons.location_off_rounded,
        title: 'GPS indisponível',
        message: 'Este dispositivo não possui GPS, então não é possível mostrar sua localização no mapa.',
        isError: true,
      ),
      MapLocationStatus.serviceDisabled => _NoticeContent(
        icon: Icons.gps_off_rounded,
        title: 'Ligue o GPS',
        message:
            'O GPS precisa estar ligado para mostrar sua localização no mapa.',
        actionLabel: 'Abrir configurações',
        onAction: onOpenLocationSettings,
        isError: true,
      ),
      MapLocationStatus.permissionDenied => _NoticeContent(
        icon: Icons.location_searching_rounded,
        title: 'Localização desativada',
        message: 'O app funciona melhor com a sua localização. Permita o acesso para ver onde você está.',
        actionLabel: 'Permitir localização',
        onAction: onRequestPermission,
      ),
      MapLocationStatus.permissionDeniedForever => _NoticeContent(
        icon: Icons.location_searching_rounded,
        title: 'Localização desativada',
        message: 'O app funciona melhor com a sua localização. Ative o acesso nas configurações do aparelho.',
        actionLabel: 'Abrir configurações',
        onAction: onOpenAppSettings,
      ),
      MapLocationStatus.unavailable => _NoticeContent(
        icon: Icons.wrong_location_rounded,
        title: 'Não foi possível obter sua localização',
        message: 'Verifique se o GPS está funcionando e tente novamente.',
        actionLabel: 'Tentar novamente',
        onAction: onRetry,
        isError: true,
      ),
      _ => null,
    };
  }
}

class _NoticeContent {
  const _NoticeContent({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.isError = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool isError;
}
