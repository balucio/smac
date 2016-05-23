<?php

class SwitcherModel {

	public
		$result = null
	;

	public function __construct() {

	}

	public function state() {

		$this->result = Db::get()->getFirstRow(
			'SELECT * FROM ultima_commutazione WHERE NOW() - data_ora <= :max_min::interval',
			[ ':max_min' => '10 minutes' ]
		);
	}

	public function on() {

	}

	public function off() {

	}

	public function reload() {

	}

	public function report_commutazioni($start, $end) {

		$this->result = Db::get()->getResultSet(
			"SELECT date_trunc('minutes', inizio) inizio,"
			     ." extract(EPOCH FROM durata) durata, stato"
			." FROM report_commutazioni(:start, :end)",
			[':start' => $start, ':end' => $end]
		);
	}
}