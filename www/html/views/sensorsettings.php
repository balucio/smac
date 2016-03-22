<?php

class SensorSettingsView extends MainView {

	const
		TPL = 'sensorsettings.tpl'
	;

	public function __construct($model) {

		parent::__construct($model, self::TPL);

		Assets::get()->addJs([
			'/js/parsley.js',
			'/js/parsley-i18n/it.js',
			'/js/bootstrap-timepicker.js',
			'/js/confirm-delete.js',
//			'/js/program-settings.js'
		]);

		Assets::get()->addCss([
			'/css/bootstrap-timepicker.css',
//			'/css/program-settings.css'
		]);
	 }

	public function render() {

		$this->addData([
			'sensori' => $this->model->get('listnoavg'),
			'sensore' => $this->model
		]);

		return parent::render();
	}
}
