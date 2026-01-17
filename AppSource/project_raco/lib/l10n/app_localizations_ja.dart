// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get app_title => 'Project Raco';

  @override
  String get by => '作成者: 神奈川山田';

  @override
  String get root_access => 'ルートアクセス:';

  @override
  String get module_installed => 'モジュール:';

  @override
  String get module_version => 'モジュールバージョン:';

  @override
  String get module_not_installed => 'インストールされていません';

  @override
  String get current_mode => '現在のモード:';

  @override
  String get select_language => '言語を選択:';

  @override
  String get power_save_desc => 'バッテリーを優先（パフォーマンス最小）';

  @override
  String get balanced_desc => 'バッテリーとパフォーマンスのバランス';

  @override
  String get performance_desc => 'パフォーマンスを優先（バッテリー最小）';

  @override
  String get clear_desc => 'すべてのアプリを終了してRAMをクリア';

  @override
  String get cooldown_desc => 'デバイスを冷却\n(2分間休ませる)';

  @override
  String get gaming_desc => 'パフォーマンスモードですべてのアプリを終了';

  @override
  String get power_save => '省電力';

  @override
  String get balanced => 'バランス';

  @override
  String get performance => 'パフォーマンス';

  @override
  String get clear => 'クリア';

  @override
  String get cooldown => '冷却';

  @override
  String get gaming_pro => 'ゲーミングプロ';

  @override
  String get about_title => 'Project Racoの改善に協力してくれた素晴らしい人々に感謝します:';

  @override
  String get about_quote => '\"偉大なコラボレーションは偉大なイノベーションにつながる\"\n~ 神奈川山田 (メイン開発者)';

  @override
  String get about_note => 'Project Racoは常に無料、オープンソース、そして改善に開かれています';

  @override
  String get credits_11 => '名前を挙げられなかったすべてのテスター';

  @override
  String get yes => 'はい';

  @override
  String get no => 'いいえ';

  @override
  String get utilities => 'ユーティリティ';

  @override
  String get utilities_title => 'ユーティリティ';

  @override
  String get search_utilities => 'ユーティリティを検索';

  @override
  String get core_tweaks_title => 'コア調整';

  @override
  String get automation_title => '自動化';

  @override
  String get system_title => 'システム';

  @override
  String get appearance_title => '外観';

  @override
  String get fix_and_tweak_title => '修正と調整';

  @override
  String get device_mitigation_title => 'デバイスの緩和';

  @override
  String get device_mitigation_description => '画面のフリーズが発生した場合にオンにします';

  @override
  String get lite_mode_title => 'ライトモード';

  @override
  String get lite_mode_description => 'パフォーマンスの軽量版、バッテリー消費は少ないがパフォーマンスの向上も少ない';

  @override
  String get life_mode_title => 'LIFEモード';

  @override
  String get life_mode_description => 'バランスモードでCPUパワーを半分にする';

  @override
  String get hamada_ai => 'HAMADA AI';

  @override
  String get hamada_ai_description => 'ゲーム開始時にパフォーマンス、画面オフ時に省電力モードへ切り替え';

  @override
  String get downscale_resolution => '解像度を下げる';

  @override
  String selected_resolution(String resolution) {
    return '選択済み: $resolution';
  }

  @override
  String get reset_resolution => 'オリジナルに戻す';

  @override
  String get hamada_ai_toggle_title => 'HAMADA AI を有効にする';

  @override
  String get hamada_ai_start_on_boot => '起動時に開始';

  @override
  String get edit_game_txt_title => 'game.txt を編集';

  @override
  String get sync_changes => '変更を同期';

  @override
  String get executing_command => '実行中...';

  @override
  String get command_executed => 'コマンドが実行されました。';

  @override
  String get command_failed => 'コマンドが失敗しました。';

  @override
  String get saving_file => '保存中...';

  @override
  String get file_saved => 'ファイルが保存されました。';

  @override
  String get file_save_failed => 'ファイルの保存に失敗しました。';

  @override
  String get reading_file => 'ファイルを読み込み中...';

  @override
  String get file_read_failed => 'ファイルの読み込みに失敗しました。';

  @override
  String get writing_service_file => 'ブートスクリプトを更新中...';

  @override
  String get service_file_updated => 'ブートスクリプトが更新されました。';

  @override
  String get service_file_update_failed => 'ブートスクリプトの更新に失敗しました。';

  @override
  String get error_no_root => 'ルートアクセスが必要です。';

  @override
  String get error_file_not_found => 'ファイルが見つかりません。';

  @override
  String get game_txt_hint => 'ゲームパッケージ名を1行に1つずつ入力...';

  @override
  String get resolution_unavailable_message => 'このデバイスでは解像度制御は利用できません。';

  @override
  String get applying_changes => '変更を適用中...';

  @override
  String get applying_new_color => '新しい色を適用しています、お待ちください...';

  @override
  String get dnd_title => 'DND スイッチ';

  @override
  String get dnd_description => 'DND の自動オン/オフ切り替え';

  @override
  String get dnd_toggle_title => 'DND 自動スイッチを有効にする';

  @override
  String get bypass_charging_title => 'バイパス充電';

  @override
  String get bypass_charging_description =>
      'サポートされているデバイスでパフォーマンス＆ゲーミングプロ中にバイパス充電を有効にする';

  @override
  String get bypass_charging_toggle => 'バイパス充電を有効にする';

  @override
  String get bypass_charging_unsupported => 'お使いのデバイスではバイパス充電はサポートされていません';

  @override
  String get bypass_charging_supported => 'お使いのデバイスではバイパス充電がサポートされています';

  @override
  String get mode_status_label => 'モード:';

  @override
  String get mode_manual => '手動';

  @override
  String get mode_hamada_ai => 'HamadaAI';

  @override
  String get please_disable_hamada_ai_first => '最初にHamadaAIを無効にしてください';

  @override
  String get background_settings_title => '背景設定';

  @override
  String get background_settings_description =>
      'アプリの背景画像、不透明度、ぼかし効果をカスタマイズします。';

  @override
  String get opacity_slider_label => '背景の不透明度';

  @override
  String get blur_slider_label => '背景のぼかし';

  @override
  String get banner_settings_title => 'バナー設定';

  @override
  String get banner_settings_description =>
      'メイン画面のバナー画像（アスペクト比16:9）をカスタマイズします。';

  @override
  String get device_name => 'デバイス名';

  @override
  String get processor => 'プロセッサ';

  @override
  String get ram => 'RAM';

  @override
  String get phone_storage => 'ストレージ';

  @override
  String get battery_capacity => 'バッテリー容量';

  @override
  String get custom_governor_title => 'カスタムガバナー';

  @override
  String get custom_governor_description =>
      'カスタムCPUガバナーを設定します。これにより、バランスモードでガバナーが設定されます';

  @override
  String get loading_governors => 'ガバナーを読み込み中...';

  @override
  String get no_governor_selected => 'なし';

  @override
  String get anya_thermal_title => 'アーニャ・メルフィッサ サーマル無効化';

  @override
  String get anya_thermal_description =>
      'パフォーマンスとゲーミングモードではサーマルを無効化し、省電力、バランス、冷却モードではサーマルを有効化します。';

  @override
  String get anya_thermal_toggle_title => 'アーニャサーマルフローステートを有効にする';

  @override
  String get system_actions_title => 'システムアクション';

  @override
  String get fstrim_title => 'Fstrim';

  @override
  String get fstrim_description => 'Androidパーティションをトリムします。';

  @override
  String get clear_cache_title => 'キャッシュをクリア';

  @override
  String get better_powersave_title => 'より良い省電力';

  @override
  String get better_powersave_description => 'CPU周波数を最小ではなく半分に制限します（省電力モードのみ）';

  @override
  String get carlotta_cpu_title => 'Carlotta CPU';

  @override
  String get carlotta_cpu_description =>
      'ターゲットCPUを変更 (警告: デバイスがクラッシュする可能性があります)';

  @override
  String build_version_title(String buildName) {
    return 'Project Raco: $buildName ビルド';
  }

  @override
  String build_by_title(String builderName) {
    return '作成者: $builderName';
  }

  @override
  String get screen_modifier_title => 'スクリーンモディファイア';

  @override
  String get screen_modifier_description =>
      '画面のカラーマトリックスと彩度を調整して、カスタム表示体験を実現します。';

  @override
  String get screen_modifier_red => '赤';

  @override
  String get screen_modifier_green => '緑';

  @override
  String get screen_modifier_blue => '青';

  @override
  String get screen_modifier_saturation => '彩度';

  @override
  String get screen_modifier_reset => 'デフォルトにリセット';

  @override
  String get screen_modifier_apply_on_boot => '起動時に適用';

  @override
  String get graphics_driver_title => 'システムグラフィックドライバ';

  @override
  String get graphics_driver_description => 'デバイスのグラフィックドライバを変更';

  @override
  String get graphics_driver_default => 'デフォルト';

  @override
  String get graphics_driver_game => 'ゲームドライバ';

  @override
  String get graphics_driver_developer => '開発者用ドライバ';

  @override
  String get current_driver => '現在:';

  @override
  String get legacy_notif_title => 'レガシー通知';

  @override
  String get legacy_notif_description => '一部のROMで通知が表示されない場合にレガシー通知を使用する';

  @override
  String get slingshot_title => 'Raco Slingshot';

  @override
  String get slingshot_description =>
      'アプリを起動する前にファイルをプリロードします。これにより、読み込み時間が短縮され、パフォーマンスが向上する可能性があります';

  @override
  String get angle_title => 'ANGLE グラフィックスを使用して起動';

  @override
  String get angle_not_supported => 'このデバイスは ANGLE グラフィックスをサポートしていません';

  @override
  String get skia_title => 'SkiaVKをデフォルトのSkiaバックエンドとして使用';

  @override
  String get preload_mode => 'プリロードモード';

  @override
  String get start_preload => 'Slingshot 開始';

  @override
  String get swipe_again_to_cancel => 'もう一度右にスワイプしてキャンセル';

  @override
  String get execution_cancelled => '実行がキャンセルされました';

  @override
  String get toast_title => 'トースト通知';

  @override
  String get toast_description => '通知の代わりにトーストを使用 (HamadaAIを使用している場合に推奨)';

  @override
  String get sandevistan_duration_title => 'サンデヴィスタン持続時間';

  @override
  String get sandevistan_duration_description => 'サンデヴィスタンの持続時間を変更 (秒)';

  @override
  String get sandevistan_duration_hint => '秒数を入力してください';

  @override
  String get sandev_egg_useless => 'おいおい！意味ないぜ！無効にしな！';

  @override
  String get sandev_egg_original => 'オリジナル重視か？何も知らないか、変えるのが怖いのか？';

  @override
  String get sandev_egg_better => 'いいぜチューム、もっと上げてもいいんだぜ';

  @override
  String get sandev_egg_david => 'なんだ？デイビッド・マルティネスにでもなるつもりか？無理だぜ';

  @override
  String get sandev_egg_smasher => 'おいおい、アダム・スマッシャーをソロで倒す気かよ！';

  @override
  String get hamada_powersave_screen_off_title => '画面オフ時に省電力';

  @override
  String get hamada_normal_interval_title => '通常間隔';

  @override
  String get hamada_screen_off_interval_title => '画面オフ時の間隔';

  @override
  String get hamada_interval_hint => '秒数を入力 (最小 2)';

  @override
  String get plugins_title => 'プラグイン';

  @override
  String get plugins_description => 'Project Racoの外部モジュールを管理およびインストール';

  @override
  String get install_plugin => 'プラグインをインストール';

  @override
  String get no_plugins_installed => 'プラグインはインストールされていません';

  @override
  String get plugin_installer => 'プラグインインストーラー';

  @override
  String get install_question => 'このプラグインをインストールしますか？';

  @override
  String get delete_plugin_title => 'プラグインの削除';

  @override
  String delete_plugin_confirm(String pluginName) {
    return '$pluginName を削除してもよろしいですか？';
  }

  @override
  String get plugin_verification_failed =>
      '検証失敗: prop内に RacoPlugin=1 が見つかりません。';

  @override
  String get plugin_script_error => 'インストールスクリプトエラー。';

  @override
  String get logs_saved => 'ログがダウンロードに保存されました。';

  @override
  String get plugin_installed_success => 'プラグインが正常にインストールされました。';

  @override
  String get plugin_uninstall_success => 'プラグインがアンインストールされました。';
}
