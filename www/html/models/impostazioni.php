<?php

class ImpostazioniModel {

	private
		$sensor,
		$program
	;

	public function __construct() {
		$this->sensor = new SensorModel();
		$this->program = new ProgramModel();
	}


	public function __get($type) {

		return $type == 'sensor' ? $this->sensor : $this->program;
	}

	public function init() {

		$this->sensor->setSid(0, SensorListModel::ALL);
		$this->program->setPid(ProgramModel::CURRENT_PROGRAM, ProgramDataModel::DAY_ALL, ProgramListModel::NONE);
	}
}