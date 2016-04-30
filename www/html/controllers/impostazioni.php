<?php

class ImpostazioniController extends BaseController {

	public function __construct($model) {

		parent::__construct($model, false);

		$this->setDefaultAction('view');
	}

	public function programmi() {

		$this->model->setPid(ProgramModel::CURRENT_PROGRAM, ProgramDataModel::DAY_ALL, ProgramListModel::NONE);
	}

	public function sensori() {

			// Get the first sensor
		$this->model->setSidForData( 1, SensorListModel::ALL );
	}

	public function generali() {

		$action = Request::Attr('action', null);

		if ($action != null) {
			$this->saveData();
			// Request::Redirect($_SERVER['PHP_SELF']);
		}
	}

	protected function saveData() {

		$sa = Request::Attr('sensore_antigelo', null);

		if (Validate::IsInteger($sa) && ( $sa == 0 || $this->model->exists($sa) ) )
			$this->model->antifreezeSensor = $sa;

		$ta = Request::Attr('temperatura_antigelo', null);

		if (Validate::IsFloatInRange($ta, Validate::MIN_TEMP, Validate::MAX_TEMP ))
			$this->model->antifreezeTemp = $ta;

		$sm = Request::Attr('sensore_manuale', null);

		if (Validate::IsInteger($sm) && ( $sm == 0 || $this->model->exists($sm)) )
			$this->model->manualSensor = $sm;

		$tm = Request::Attr('temperatura_manuale', null);

		if (Validate::IsFloatInRange($tm, Validate::MIN_TEMP, Validate::MAX_TEMP ))
			$this->model->manualTemp = $tm;

		$pr = Request::Attr('pin_rele_gpio', null);

		if (Validate::IsValidGpioPin($pr))
			$this->model->pinRele = $pr;
	}

}