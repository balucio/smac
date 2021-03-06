<?php

class SensorBaseStatsController extends BaseController {

	const

		// Intevallo predefinito tra date (1 ora)
		DEF_INTERVAL = 3600,
		// Intervallo minimo tra date (5 min)
		MIN_INTERVAL = 300,
		// Intevallo Massimo tra date
		MAX_INTERVAL = 8035200,
		// Default punti da processare
		DEF_POINT_NUM = 100,
		// Minimo punti da processare
		MIN_POINT_NUM = 30,
		// Numero massimo di punti da processare
		MAX_POINT_NUM = 300
	;

	public function __construct($model, $init = true) {

		parent::__construct($model, $init);
		$this->setDefaultAction('temperatura');
	}

	public function temperatura() {

		$this->model->setPhysicalType(SensorStatsModel::TEMPERATURA);
	}

	public function umidita() {
		$this->model->setPhysicalType(SensorStatsModel::UMIDITA);
	}

	protected function initFromRequest() {

		$sid = Request::Attr('sensor', null);

		if (!is_null($sid)
			&& ($sid == '0' || Validate::IsPositiveInt($sid))
		) {
			$this->model->setSensorId($sid);
		}

		$points = Request::Attr('points_number', null);
		$points = Validate::IsPositiveInt($points)
			? min(max($points, self::MIN_POINT_NUM), self::MAX_POINT_NUM)
			: self::DEF_POINT_NUM
		;
	}

	protected function setDate($checkDateRange = true) {

		$int = Request::Attr('interval', null);
		$int = Validate::IsPositiveInt($int)
			? min(max($int, self::MIN_INTERVAL), self::MAX_INTERVAL)
			: self::DEF_INTERVAL;

		$sd = Request::Attr('start_date', null);
		$ed = Request::Attr('end_date', null);

		$vsd = Validate::IsValidTimeStamp($sd);
		$ved = Validate::IsValidTimeStamp($ed);

		if ( $vsd && $ved ) {

			// Mi assicuro che data_inizio < data_fine
			if ( $sd > $ed ) {
				$tmp = $sd;
				$sd = $ed;
				$ed = $tmp;
			} else if ( $sd == $ed ) {
				$sd = $ed - $int;
			}

			// Verifica intervallo date solo per SensorStats
			if ($checkDateRange && ( $ed - $sd > self::MAX_INTERVAL )) {
					$sd = $ed - self::MAX_INTERVAL;
			}

			$this->model->setStartDate( Db::TimestampWt( $sd ) );
			$this->model->setEndDate( Db::TimestampWt( $ed ) );

		} else if ( $vsd ) {

			$this->model->setStartDate( Db::TimestampWt( $sd ) );
			$this->model->setEndDate( Db::TimestampWt( $sd + $int ) );

		} else {

			$ed = $ved ? $ed : time();

			$this->model->setStartDate( Db::TimestampWt( $ed - $int ) );
			$this->model->setEndDate( Db::TimestampWt( $ed ) );
		}
	}
}