<?php

class ImpostazioniModel {

	private
		$programma,
		$pid
	;

	public function __construct() {

		$this->programma = new ProgrammaModel();
	}

	public function __get($data) {
		return $this->programma->$data;
	}

	public function dettaglioCompleto($pid) {

		if (false !== $pid = $this->programma->programList($pid))
			$this->programma->programData($pid, 0);

	}

}