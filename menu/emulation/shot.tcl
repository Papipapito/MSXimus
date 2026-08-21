# Headless capture script for MSXnano main menu verification
set save_settings_on_exit off
set throttle off
after time 6 {
	screenshot -raw -doublesize C:/Users/alber/MSXnano/_menu_shot.png
	exit
}
