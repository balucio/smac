<?php

class SensorDataController extends GenericController {
	const
		TEMPERATURA = 'temperatura',
		UMIDITA = 'umidita',

		H_SECONDS = 3600,
		// 3 months
		MAX_RANGE = 8035200
	;

	private
		$sid = null,
		$interval = null,
		$dateStart = null,
		$measure = null,
	;

	public function __construct($model) {

		$this->model = $model;
		$this->sid = (int)Request::Attr('sensor', null);
	}

	public function setSensorId($sid = null) {

		$sid !== null && $this->sid = (int)$sid;

		$this->model->setSensorId($this->sid);
	}

	public function getStats($type, $sensor = null, $start_epoch = null, $end_epoch = null) {

		$this->getStatsParams($sid, $measure, $start_epoch , $end_epoch)

		$cUtc = Db::UTC();

		$start_epoch = (
			( is_null($start_epoch)
				|| ( Db::UTC($start_epoch) - $cUtc ) > Self::MAX_RANGE
			)) ? ( $cUtc - $this->interval)
			  : Db::UTC($start_epoch)
		;

		$end_epoch = Db::UTC($end_epoch);
		$end_epoch = $end_epoch > $start_epoch ? $end_epoch : $cUtc;

		if ($end_epoch - $start_epoch > Self::MAX_RANGE)
			$end_epoch = $start_epoch + Self::MAX_RANGE;

		$this->model->setPhysicalType($type)
			->setSensorId($sid)
			->setStartDate( Db::Timestamp($start_epoch) )
			->setEndDate( Db::Timestamp($end_epoch) );

		$this->isInit = true;

		return $this;
	}

	protected getStatsParams($sid, $measure, $start_epoch , $end_epoch) {

		$sid !== null && $this->sid = $sid;

		$measure = self::isValidMeasure($measure)
			? $measure
			: Request::Attr('measure', self::TEMPERATURA)
		;

		$cd = Db::UTC();

		$ds =  $start_epoch ?: Request::Attr('date_start', $cd - self::H_SECONDS);
		$de =  $end_epoch ?: Request::Attr('date_end', $cd);

		$int = (int)Request::Attr('interval', self::H_SECONDS);
		$int = Validate::IsPositiveInt( $int ) ? $int : self::H_SECONDS;

		$vds = Validate::IsPositiveInt( $ds );
		$vde = Validate::IsPositiveInt( $de );

		if ( $vds && $vde ) {

			$this->dateStart = Db::UTC(min($de, $ds));
			$this->dateEnd = Db::UTC(max($de, $ds));

		} else if ( !$vde ) {

			$this->dateStart = Db::UTC($ds);
			$this->dateEnd = Db::UTC($ds - $int);

		} else if ( !$vds ) {

			$this->dateStart = Db::UTC($de - $int);
			$this->dateEnd = Db::UTC($de);
		}

		$this->measure = self::isValidMeasure($measure) ? $measure : self::TEMPERATURA;
	}


	private static isValidMeasure($measure) {

		static $measures = array (self::TEMPERATURA, self::UMIDITA);

		return in_array($measure, $measures);

	}

}