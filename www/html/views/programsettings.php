<?php

class ProgramSettingsView extends MainView {

	const
		TPL = 'programsettings.tpl'
	;

	public function __construct($model) {

		parent::__construct($model, self::TPL);

		Assets::get()->addJs([
			'/js/parsley.js',
			'/js/parsley-i18n/it.js',
			'/js/bootstrap-timepicker.js',
			'/js/confirm-delete.js',
			'/js/program-settings.js'
		]);

		Assets::get()->addCss([
			'/css/bootstrap-timepicker.css',
			'/css/program-settings.css'
		]);
	 }

	public function render() {

		$this->addData([
			'programmi' => $this->model->list,
			'programma' => $this->model,
			'temperature' => isset($this->model->temperature) ? $this->model->temperature : null,
		]);

		return parent::render();
	}
/*
	private static function js() {
		return "$('#programmazione-settimanale a').click(function (e) {
			e.preventDefault()
			$(this).tab('show')
		})";
	}
*/
}
