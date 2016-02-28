<?php

class StatoSistemaView {

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

		$tpl = Template::get()->loadTemplate('statosistema.tpl');

		return $tpl->render([
			'programmi' => $this->model->list,
			'antigelo' => $this->model->antigelo,
			'temperature' => $this->model->temperature,
			'rif_temp_attuale' => $this->model->rif_temp_attuale

		]);
	}

}