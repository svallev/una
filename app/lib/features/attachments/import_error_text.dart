import '../../domain/entities/image_type.dart';
import '../../domain/ports/image_importer.dart';
import '../../l10n/generated/app_localizations.dart';

/// Aviso de cada error de importación (spec 007 §5).
String importErrorText(AppLocalizations l10n, ImageImportError error) =>
    switch (error) {
      ImageImportError.unsupportedType => l10n.errImageType,
      ImageImportError.tooLarge => l10n.errImageTooBig(
        ImageLimits.maxBytesInMb,
      ),
      ImageImportError.tooManyPixels => l10n.errImageTooManyPixels(
        ImageLimits.maxMegapixels,
      ),
      ImageImportError.unreadable => l10n.errImageUnreadable,
      ImageImportError.noCamera => l10n.errNoCamera,
      ImageImportError.noSpace => l10n.storageErrorNoSpace,
    };
