<?php

class ImpostazioniView extends MainView {

	const
		TPL = 'impostazioni.tpl'
	;

	public function __construct($model) {

		parent::__construct($model, self::TPL);
	}

	public function render() {

//		$sensori = new SensorSettingsView(
//			$this->model->sensor
//		);

		$programmi = new ProgramSettingsView(
			$this->model->program
		);

		$this->addData([
//			'sensori' => $sensori->render(),
			'programmi' => $programmi->render(),
		]);

		return parent::render();
	}
}