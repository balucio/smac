<?php

class SituazioneView extends MainView {

	const
		TPL = 'situazione.tpl'
	;

	public function __construct($model) {

		parent::__construct($model, self::TPL);

		Assets::get()->addJs([
			'/js/highcharts.js',
			'/js/highcharts-i18n/defaults-it_IT.js'
		]);
	}

	public function render() {

		$situazione = new StatoSensoriView(
			$this->model->sensor
		);

		$programmi = new StatoSistemaView(
			$this->model->program
		);

		$this->addData([
			'situazione' => $situazione->render(),
			'programmazione' => $programmi->render()
		]);

		return parent::render();
	}
}