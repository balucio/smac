<?php

class ImpostazioniController extends BaseController {

	public function __construct($model) {

		parent::__construct($model, false);

		$this->setDefaultAction('view');
	}

	public function programmi() {

		$this->model->setPid(ProgramModel::CURRENT_PROGRAM, ProgramDataModel::DAY_ALL, ProgramListModel::NONE);
	}

	public function sensori() {

			// Get the first sensor
		$this->model->setSid( 1, SensorListModel::ALL );
	}

}