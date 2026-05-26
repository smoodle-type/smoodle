pub mod yaml;
pub mod commands;

use commands::{deploy, settings, status, telemetry, user_dict};

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
  tauri::Builder::default()
    .plugin(tauri_plugin_single_instance::init(|_app, _argv, _cwd| {}))
    .setup(|app| {
      if cfg!(debug_assertions) {
        app.handle().plugin(
          tauri_plugin_log::Builder::default()
            .level(log::LevelFilter::Info)
            .build(),
        )?;
      }
      Ok(())
    })
    .invoke_handler(tauri::generate_handler![
      user_dict::read_user_dict,
      user_dict::add_user_word,
      user_dict::delete_user_word,
      deploy::deploy_squirrel,
      status::smoodle_running,
      status::schema_compile_log,
      status::dict_counts,
      settings::read_default_custom,
      settings::write_default_custom,
      settings::open_rime_folder,
      settings::reset_to_defaults,
      telemetry::telemetry_state,
      telemetry::telemetry_set_opt_in,
      telemetry::telemetry_forget,
    ])
    .run(tauri::generate_context!())
    .expect("error while running tauri application");
}
