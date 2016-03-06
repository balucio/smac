<?php

class SituazioneModel {

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

		$this->sensor->setSid(0, SensorListModel::ENABLED);
		$this->program->setPid();
	}
}