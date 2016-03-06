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

	public function __get($v) {
		return $v == 'list'
			? $this->list->get()
			: $this->data->$v
		;
	}

	public function setPid($pid = null) {

		$this->data->setPid(
			$pid = $pid ?: $this->data->getDefault(),
			date('N')
		);
		$this->list->enumerate($pid);
	}
}