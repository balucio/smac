<?php

class Route {

	public
		$model,
		$view,
		$controller;

	public function __construct($model, $view, $controller) {

		$this->model = $model .'Model';
		$this->view = $view .'View';
		$this->controller = $controller . 'Controller';
	}

	public function __get($type) {

		switch ($type) {

			case 'model': return $this->model;
			case 'view' : return $this->view;
			case 'controller' : return $this->controller;

		}

		throw new InvalidArgumentException("Invalid route $type component", 1);
	}
}


class Router {

	const DEFAULT_MAINROUTE = 'situazione';
	const DEFAULT_SUBROUTE = 'view';

	private static $table = null;

	public function __construct() {
		self::$table = self::initTable();
	}

	public function __get($r) {

		list($m, $s) = self::getRoutePath($r);
		return isset(self::$table[$m][$s]) ? self::$table[$m][$s] : null;
	}

	public function __isset($r) {

		list($m, $s) = self::getRoutePath($r);
		return isset(self::$table[$m][$s]);
	}

	private static function getRoutePath($r) {

		list($m, $s) = explode('.', strtolower("{$r}."), 2);
		$s = rtrim($s, ".");

		return [ $m, $s ];
	}

	private static function initTable() {
		return [
			// Pagina situazione sistema
			'situazione' => [
				'view' => new Route('Situazione', 'Situazione', 'Situazione')
			],
			'sensor' => [
				'view' => new Route('SensorData', 'SensorData', 'SensorData'),
				'stats' => new Route('SensorStats', 'SensorStats', 'SensorStats'),
			],
			'program' => [
				'view' => new Route('ProgramData', 'ProgramData', 'ProgramData'),
				'savedefault' => new Route('ProgramData', 'SaveProgram', 'ProgramData'),
				'getschedule' => new Route('ProgramData', 'ProgramSchedule', 'ProgramData'),
				'getdata' => new Route('ProgramData', 'ProgramDataRaw', 'ProgramData'),
				'getsensorlist' => new Route('SensorList', 'SensorProgramList', 'SensorProgramList'),
				'getlist' => new Route('ProgramList', 'ProgramList', 'ProgramData'),
				'createorupdate' => new Route('ProgramData', 'ProgramOpResult', 'ProgramData'),
				'createorupdateschedule' => new Route('ProgramData', 'ProgramOpResult', 'ProgramData'),
				'delete' => new Route('ProgramData', 'ProgramOpResult', 'ProgramData'),
				'deleteschedule' => new Route('ProgramData', 'ProgramOpResult', 'ProgramData')
			],
			'impostazioni' => [
				'generali' => new Route('', 'Impostazioni', 'Impostazioni'),
				'sensori' => new Route('', 'Impostazioni', 'Impostazioni'),
				'programmi' => new Route('Program', 'ProgramSettings', 'Impostazioni')
			]
			// Programmi
		];
	}

}
