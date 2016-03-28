<?php

class DriverListModel {

	private

		$list = null,

		$selected = null
	;

	public function __construct($selected = 0) {

		$this->selected = $selected;
	}

	public function get() { return $this->list; }

	public function enumerate($selected = 0) {

		$selected != $this->selected
			&& $this->selected = $selected;

		$this->list = [];

		foreach ( Db::get()->getResultSet("SELECT id, nome FROM driver_sensori") as $v ) {

			$k = $v['id'];
			$this->list[$k] = $v;

			$this->list[$k]['selected'] = ( $selected == $k ) ? 'selected' : '';
		}
	}
}