<?php

class ImpostazioniModel {

	private
		$programma = null
	;

	public function __construct() {

		$this->programma = new ProgrammaModel();
 	}

    public function __get($data) {
        return $this->$data;
    }
}