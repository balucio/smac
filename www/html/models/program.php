<?php

class ProgramModel {

	private
		$list = null,
		$data = null
	;

	public function __construct() {

		$this->list = new ProgramListModel();
		$this->data = new ProgramDataModel();

 	}

 	public function __get($name) {
 		return $name == 'list'
 			? $this->list->getList()
 			: $this->data->$name;
 	}

	public function initData() {

		$dpid = $this->getDefault();

		$this->programList($dpid);
		$this->programData($dpid);
	}

	public function setDefault($pid) {

		if ($this->data->programExists($pid))
			Db::get()->saveSetting(Db::CURR_PROGRAM, $pid);
		else {
			error_log("Id programma $pid non esistente");
			return false;
		}

		return true;
	}

	public function getDefault() {

		return Db::get()->readSetting(Db::CURR_PROGRAM, '-1');
	}

	private function programData($pid) {

		$this->data->initData($pid, date('N'));

	}

	private function programList($pid) {

		$this->list->initData($pid, ProgramListModel::ALL);

	}
}