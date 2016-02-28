<?php

class ProgramStatusView {

	private
		$model,
		$controller
	;

	public function __construct($controller, $model) {

		$this->controller = $controller;
		$this->model = $model;

		Assets::get()->addJs('/js/rainbow.js');
		Assets::get()->addJs('/js/statosistema.js');
	}

	public function render() {

		$tpl = Template::get()->loadTemplate('statosistema');
		$dcr = new Decorator();
		$progr = $this->model->programdata();

		return $tpl->render([
			'special_program' => $this->model->programlist(ProgramStatusModel::SPECIAL_PROGRAM),
			'other_program' => $this->model->programlist(ProgramStatusModel::OTHER_PROGRAM),
			'decorateTemperature' => [$dcr, 'decorateTemperature'],
			'decorateUmidity' => [$dcr, 'decorateUmidity'],
			'antigelo' => $progr->antigelo,
			'temperature' => $progr->temperature,
			'rif_temp_attuale' => $progr->rif_temp_attuale

		]);
	}

}