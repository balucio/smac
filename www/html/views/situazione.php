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

		$tpl = Template::get()->loadTemplate('situazione');

		$situazione = new SensorStatusView(
			$this->controller,
			$this->model->situazione()
		);

		$programmi = new ProgramStatusView(
			$this->controller,
			$this->model->programmazione()
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