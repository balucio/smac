<?php

class StatsController extends GenericController {

	const

		// Secondi in un ora
		DEF_INTERVAL = 3600,
		// Tre mesi
		MAX_INTERVAL = 8035200
	;

	public function __construct($model) {

		$this->model = $model;
	}

	public function temperatura() {

		$this->setModelPars(AndamentoModel::TEMPERATURA);
	}

	public function umidita() {
		$this->setModelPars(AndamentoModel::UMIDITA);
	}

	private function setModelPars($grapType) {

		$this->model->setPhysicalType($grapType);

		$sid = Request::Attr('sensor', null);

		if ($sid === null || $sid != 0 || !Validate::IsPositiveInt($sid))
			return;

		$this->model->setSensorId($sid);

		$int = Request::Attr('interval', null);
		$int = Validate::IsPositiveInt($int) ? $int : self::DEF_INTERVAL;

		if ($int > self::MAX_INTERVAL)
			$int = self:MAX_INTERVAL;

		$sd = Request::Attr('start_date', null);
		$ed = Request::Attr('end_date', null);

		$vsd = Validate::IsValidTimeStamp($sd);
		$ved = Validate::IsValidTimeStamp($ed);

		if ( $vsd && $ved ) {

			$cds = min($sd, $ed);
			$cde = max($sd, $ed);

			if ($cde - $cds > self::MAX_INTERVAL)
				$cds = $cde - self::MAX_INTERVAL;

		} else if ( $vsd ) {

			$cds = $sd;
			$cde = $sd + $int;
		}

		$this->model->setStartDate($cds)
		$this->model->setEndDate($cde);
	}




}