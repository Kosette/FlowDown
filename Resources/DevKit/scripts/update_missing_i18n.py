#!/usr/bin/env python3
"""
Update missing i18n translations in Localizable.xcstrings.
This script adds missing English localizations and fixes 'new' state translations.
"""

import sys

from i18n_tools import (
    DEFAULT_KEEP_LANGUAGES,
    default_file_path,
    load_strings,
    print_update_summary,
    save_strings,
    update_missing_translations,
)

# Populate this map with explicit translations when introducing new keys.
# Format: {"Key": {"zh-Hans": "示例", "es": "Ejemplo"}}
NEW_STRINGS: dict[str, dict[str, str]] = {
    "Completions Format": {
        "de": "Completions-Format",
        "es": "Formato de completados",
        "fr": "Format des complétions",
        "ja": "コンプリーション形式",
        "ko": "Completions 형식",
        "zh-Hans": "补全格式",
    },
    "Export Settings": {
        "de": "Einstellungen exportieren",
        "es": "Exportar ajustes",
        "fr": "Exporter les réglages",
        "ja": "設定を書き出す",
        "ko": "설정 내보내기",
        "zh-Hans": "导出设置",
    },
    "Export app preferences and model configurations without conversations.": {
        "de": "App-Einstellungen und Modellkonfigurationen ohne Unterhaltungen exportieren.",
        "es": "Exportar preferencias de la app y configuraciones de modelos sin conversaciones.",
        "fr": "Exporter les préférences de l’app et les configurations de modèles sans les conversations.",
        "ja": "会話を含めずにアプリの設定とモデル構成をエクスポートします。",
        "ko": "대화를 제외하고 앱 환경설정과 모델 구성을 내보냅니다.",
        "zh-Hans": "在不包含会话的情况下导出应用偏好和模型配置。",
    },
    "Exported database contains all conversations data and cloud model configurations, but does not include local model data (weights). Use Settings Backup to export application preferences.": {
        "de": "Die exportierte Datenbank enthält alle Gesprächsdaten und Cloud-Modellkonfigurationen, schließt jedoch lokale Modelldaten (Gewichte) aus. Verwende die Einstellungen-Sicherung, um App-Einstellungen zu exportieren.",
        "es": "La base de datos exportada incluye todas las conversaciones y configuraciones de modelos en la nube, pero no incluye los datos de modelos locales (pesos). Usa la copia de seguridad de ajustes para exportar las preferencias de la aplicación.",
        "fr": "La base de données exportée inclut toutes les conversations et les configurations de modèles cloud, mais exclut les données des modèles locaux (poids). Utilisez la sauvegarde des réglages pour exporter les préférences de l’app.",
        "ja": "エクスポートされたデータベースにはすべての会話データとクラウドモデルの設定が含まれますが、ローカルモデルのデータ（重み）は含まれません。アプリの設定を出力するには設定バックアップを使用してください。",
        "ko": "내보낸 데이터베이스에는 모든 대화 데이터와 클라우드 모델 설정이 포함되지만 로컬 모델 데이터(가중치)는 포함되지 않습니다. 앱 환경설정을 내보내려면 설정 백업을 사용하세요.",
        "zh-Hans": "导出的数据库包含所有会话数据和云端模型配置，但不包含本地模型数据（权重）。要导出应用偏好，请使用设置备份。",
    },
    "Exporting": {
        "de": "Exportiere",
        "es": "Exportando",
        "fr": "Exportation",
        "ja": "書き出し中",
        "ko": "내보내는 중",
        "zh-Hans": "正在导出",
    },
    "FlowDown Settings Backup %@": {
        "de": "FlowDown-Einstellungen-Backup %@",
        "es": "Copia de seguridad de ajustes de FlowDown %@",
        "fr": "Sauvegarde des réglages FlowDown %@",
        "ja": "FlowDown 設定バックアップ %@",
        "ko": "FlowDown 설정 백업 %@",
        "zh-Hans": "FlowDown 设置备份 %@",
    },
    "FlowDown will close now to apply imported settings.": {
        "de": "FlowDown wird jetzt beendet, um die importierten Einstellungen anzuwenden.",
        "es": "FlowDown se cerrará ahora para aplicar los ajustes importados.",
        "fr": "FlowDown va se fermer pour appliquer les réglages importés.",
        "ja": "インポートした設定を適用するため、FlowDown を終了します。",
        "ko": "가져온 설정을 적용하기 위해 지금 FlowDown이 종료됩니다.",
        "zh-Hans": "FlowDown 将立即关闭以应用导入的设置。",
    },
    "Import Settings": {
        "de": "Einstellungen importieren",
        "es": "Importar ajustes",
        "fr": "Importer les réglages",
        "ja": "設定を読み込む",
        "ko": "설정 가져오기",
        "zh-Hans": "导入设置",
    },
    "Importing": {
        "de": "Importiere",
        "es": "Importando",
        "fr": "Importation en cours",
        "ja": "読み込み中",
        "ko": "가져오는 중",
        "zh-Hans": "正在导入",
    },
    "No configurable settings were found to export.": {
        "de": "Keine konfigurierbaren Einstellungen zum Exportieren gefunden.",
        "es": "No se encontraron ajustes configurables para exportar.",
        "fr": "Aucun réglage configurable trouvé à exporter.",
        "ja": "書き出せる設定が見つかりません。",
        "ko": "내보낼 수 있는 설정을 찾지 못했습니다.",
        "zh-Hans": "没有找到可导出的可配置设置。",
    },
    "Restore a settings backup. The app will exit after import.": {
        "de": "Eine Einstellungs-Sicherung wiederherstellen. Die App beendet sich nach dem Import.",
        "es": "Restaurar una copia de seguridad de ajustes. La app se cerrará tras la importación.",
        "fr": "Restaurer une sauvegarde des réglages. L’app se fermera après l’import.",
        "ja": "設定バックアップを復元します。インポート後にアプリは終了します。",
        "ko": "설정 백업을 복원합니다. 가져오기 후 앱이 종료됩니다.",
        "zh-Hans": "恢复设置备份。导入完成后应用将退出。",
    },
    "Settings Backup": {
        "de": "Einstellungen-Backup",
        "es": "Copia de seguridad de ajustes",
        "fr": "Sauvegarde des réglages",
        "ja": "設定バックアップ",
        "ko": "설정 백업",
        "zh-Hans": "设置备份",
    },
    "Settings backup is only supported when using UserDefaults storage.": {
        "de": "Einstellungs-Backups werden nur bei Verwendung von UserDefaults unterstützt.",
        "es": "La copia de seguridad de ajustes solo se admite cuando se usa el almacenamiento UserDefaults.",
        "fr": "La sauvegarde des réglages est uniquement prise en charge avec le stockage UserDefaults.",
        "ja": "設定バックアップは UserDefaults ストレージを使用している場合にのみサポートされます。",
        "ko": "설정 백업은 UserDefaults 저장소를 사용할 때만 지원됩니다.",
        "zh-Hans": "仅在使用 UserDefaults 存储时支持设置备份。",
    },
    "Settings backups only include configurable preferences and model selections. Conversations and local model weights remain separate.": {
        "de": "Einstellungs-Backups enthalten nur konfigurierbare Präferenzen und Modellauswahlen. Unterhaltungen und lokale Modellgewichte bleiben getrennt.",
        "es": "Las copias de seguridad de ajustes solo incluyen preferencias configurables y selecciones de modelos. Las conversaciones y los pesos de modelos locales permanecen aparte.",
        "fr": "Les sauvegardes des réglages incluent uniquement les préférences configurables et les sélections de modèles. Les conversations et les poids des modèles locaux restent séparés.",
        "ja": "設定バックアップには、設定可能なプリファレンスとモデル選択のみが含まれます。会話やローカルモデルの重みは含まれません。",
        "ko": "설정 백업에는 설정 가능한 환경설정과 모델 선택만 포함됩니다. 대화와 로컬 모델 가중치는 별도로 유지됩니다.",
        "zh-Hans": "设置备份仅包含可配置偏好和模型选择。会话记录和本地模型权重不会包含在内。",
    },
    "The selected settings backup is invalid or from an incompatible version.": {
        "de": "Die ausgewählte Einstellungen-Sicherung ist ungültig oder stammt aus einer nicht kompatiblen Version.",
        "es": "La copia de seguridad de ajustes seleccionada no es válida o pertenece a una versión incompatible.",
        "fr": "La sauvegarde des réglages sélectionnée est invalide ou provient d’une version incompatible.",
        "ja": "選択した設定バックアップが無効か、互換性のないバージョンのものです。",
        "ko": "선택한 설정 백업이 유효하지 않거나 호환되지 않는 버전에서 생성되었습니다.",
        "zh-Hans": "所选的设置备份无效或来自不兼容的版本。",
    },
}


if __name__ == "__main__":
    file_path = sys.argv[1] if len(sys.argv) > 1 else default_file_path()

    data = load_strings(file_path)
    counts = update_missing_translations(
        data,
        new_strings=NEW_STRINGS,
        keep_languages=DEFAULT_KEEP_LANGUAGES,
    )
    save_strings(file_path, data)

    print_update_summary(file_path, counts)

