<?php

class ProgramModel {

	const
		CURRENT_PROGRAM = null
	;

	private
		$list = null,
		$data = null
	;

	public function __construct() {

		$this->list = new ProgramListModel();
		$this->data = new ProgramDataModel();

 	}

 	public function __isset($v) {
 		return $v == 'list'
 			? ($this->list ? true : false )
 			: ($this->data->get() !== null ? $this->data->__isset($v) : false );
 	}

	public function __get($v) {
		return $v == 'list'
			? $this->list->get()
			: $this->data->$v
		;
	}

	public function setPid(
		$pid = self::CURRENT_PROGRAM,
		$day = ProgramDataModel::DAY_NOW,
		$include = ProgramListModel::ALL
	) {

		// Verifico che il pid passato esista veramente
		$pid = $pid === self::CURRENT_PROGRAM ? $this->data->getDefault() : $pid;

		// Non è detto che il pid sia incluso in elenco
		$pid = $this->list->enumerate($pid, $include);

		$day = $day === ProgramDataModel::DAY_NOW ? date('N') : $day;
		// Se pid è null significa che nell'elenco non esiste il programma
		// da selezionare pertanto è inutile ottenere i dati
		if ($pid !== null)
			$this->data->setPid($pid, $day);
	}
}