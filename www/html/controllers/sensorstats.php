<?php

class SensorStatsController extends GenericController {

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

		$this->setModelPars(SensorStatsModel::TEMPERATURA);
	}

	public function umidita() {
		$this->setModelPars(SensorStatsModel::UMIDITA);
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
			$int = self::MAX_INTERVAL;

		$sd = Request::Attr('start_date', null);
		$ed = Request::Attr('end_date', null);

		$vsd = Validate::IsValidTimeStamp($sd);
		$ved = Validate::IsValidTimeStamp($ed);

		if ( $vsd && $ved ) {

			if ( $sd > $ed ) {
				$tmp = $sd;
				$sd = $ed;
				$ed = $tmp;
			} else if ( $sd == $ed ) {
				$sd = $ed - $int;
			}

			if ( $ed - $sd > self::MAX_INTERVAL )
				$sd = $ed - self::MAX_INTERVAL;

			$this->model->setStartDate( Db::TimestampWt( $sd ) );
			$this->model->setEndDate( Db::TimestampWt( $ed ) );

		} else if ( $vsd ) {

			$this->model->setStartDate( Db::TimestampWt( $sd ) );
			$this->model->setEndDate( Db::TimestampWt( $sd + $int ) );

		} else if ( $ved ) {

			$this->model->setStartDate( Db::TimestampWt( $ed - $int ) );
			$this->model->setEndDate( Db::TimestampWt( $ed ) );
		}
	}




}