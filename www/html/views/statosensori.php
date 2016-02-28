<?php

class StatoSensoriView {

	private
		$model,
		$controller
	;

	public function __construct($controller, $model) {

		$this->controller = $controller;
		$this->model = $model;

		Assets::get()->addJs('/js/situazione.js');
	}

	public function render() {

		$tpl = Template::get()->loadTemplate('statosensori.tpl');

		return $tpl->render([
			'sensore' => $this->model->getData(),
			'sensori' => $this->model->getList()
		]);
	}

}