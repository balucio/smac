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
 			? true
 			: $this->data->__isset($v);
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

		$this->data->setPid($pid, $day);
	}
}