<?php

class SensorDataController extends BaseController {

	private
		$sid = null
	;

	public function __construct($model, $init = true) {

		parent::__construct($model, $init);
		$this->setDefaultAction('getMeasure');
	}

	public function getMeasure() {

		$this->sid = (int)($this->model->exists($this->sid) ? $this->sid : 0);
		$this->model->collectEnviromentalData($this->sid);
	}

	public function getData() {
		$this->sid = (int)($this->model->exists($this->sid) ? $this->sid : 0);

		$this->model->collectData($this->sid);
	}

	public function delete() {

 		if (!Validate::IsPositiveInt( $this->sid ))
			return;

		$this->model->delete($this->sid);

 	}

	public function createOrUpdate() {

		$sid = Request::Attr('sensor', null);

			// Verifico che il sid originario sia comunque corretto
		if ($sid != $this->sid)
			return;

		$driver = Request::Attr('driver', null);

		if (!Validate::IsPositiveInt( $driver ))
			return;

		$p = [
			'sid' => $sid,
			'driver' => $driver,
			'inaverage' => Request::Attr('inaverage', null) == 't',
			'enabled' => Request::Attr('enabled', null) == 't'
		];

			// Verifico presenza di nome programma, descrizione e temperature
		foreach (['name', 'description', 'parameters'] as $k) {
			$v = Request::Attr($k, null);
			if (empty($v))
				return;
			$p[$k] = $v;
		}

		$this->model->updateSensor($p);
	}


	protected function initFromRequest() {

		$this->sid = Request::Attr('sensor', null);

	}
}