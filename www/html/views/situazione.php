<?php

class SituazioneView {

	private
		$model,
		$controller
	;

	public function __construct($controller, $model) {

		$this->controller = $controller;
		$this->model = $model;
	}

	public function render() {

		$tpl = Template::get()->loadTemplate('situazione.tpl');

		$situazione = new StatoSensoriView(
			$this->controller,
			$this->model->getSensor()
		);

		$programmi = new StatoSistemaView(
			$this->controller,
			$this->model->getProgram()
		);

		return $tpl->render([
			'css' => Assets::get()->Css(),
			'js' => Assets::get()->Js(),
			'sit_selected' => 'active',
			'situazione' => $situazione->render(),
			'programmazione' => $programmi->render()
		]);
	}

}