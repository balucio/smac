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
			'/js/sensor-settings.js'
		]);

		Assets::get()->addCss([
			'/css/sensor-settings.css'
		]);

		Assets::get()->addOnReadyJs('
			$(function () {
				$(\'[data-toggle="tooltip"]\').tooltip({trigger : "click", container : "body"});
			})
		');
	 }

	public function render() {

		$this->addData([
			'sensori' => $this->model->get('listnoavg'),
			'sensore' => $this->model->get('data')
		]);

		return parent::render();
	}
}
