<?php

class SwitcherModel {

	const
		TIMEOUT_BIN = "/usr/bin/timeout",
		SWITCHER_BIN = "switcher_comunicator.py"
	;
	public
		$result = null
	;

	public function __construct() {

	}

	public function state() {

		if ($this->send_swicher_command('state', $res))
			$this->result = $res;
	}

	public function on() {

		if ($this->send_swicher_command('on', $res))
			$this->result = $res == 'True' ? true : false;
	}

	public function off() {

		if ($this->send_swicher_command('off', $res))
			$this->result = $res == 'True' ? true : false;
	}

	public function reload() {

		if ($this->send_swicher_command('reload', $res))
			$this->result = $res == 'True' ? true : false;
	}

	private function send_swicher_command($params, &$out, $timeout=5) {

		is_array($params)
			|| $params = array($params);

		$esc_exe = escapeshellcmd(
			APP_DIR . DIRECTORY_SEPARATOR . 'bin' . DIRECTORY_SEPARATOR . self::SWITCHER_BIN
		);

		foreach ($params as &$p)
			$p = escapeshellarg($p);


		$command  = escapeshellcmd(self::TIMEOUT_BIN) . ' ' . escapeshellarg($timeout)
			. ' ' . $esc_exe  . ' ' . implode(' ', $params);

		$out = exec( $command, $full_out, $ret );

		return $ret == 0;
	}
}