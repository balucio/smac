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

	public function initData() {

		$this->sensor->initData();
		$this->program->initData();

	}

	public function getSensor() {
		return $this->sensor;
	}

	public function getProgram() {
		return $this->program;
	}

}