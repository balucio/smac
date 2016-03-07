<?php

class ProgramSettingsView extends BaseView {


	public function __construct($model) {

		parent::__construct($model);
			// Assets::get()->addJs('/js/rainbow.js');
			Assets::get()->addCss('/css/program-settings.css');
	 }

	public function render() {

		$tpl = Template::get()->loadTemplate('programsettings.tpl');
d($this->model);
		return $tpl->render([
			'programmi' => $this->model->list,
			'programma' => $this->model,
			'temperature' => $this->model->temperature,
			'tabactivate' => ''
		]);
	}

	private static function js() {
		return "$('#programmazione-settimanale a').click(function (e) {
			e.preventDefault()
			$(this).tab('show')
		})";
	}

}