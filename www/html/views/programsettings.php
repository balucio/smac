<?php

class ProgramSettingsView extends MainView {

	const
		TPL = 'programsettings.tpl'
	;

	public function __construct($model) {

		parent::__construct($model, self::TPL);
		// Assets::get()->addJs('/js/rainbow.js');
		Assets::get()->addCss('/css/program-settings.css');
	 }

	public function render() {

		$this->addData([
			'programmi' => $this->model->list,
			'programma' => $this->model,
			'temperature' => $this->model->temperature,
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
