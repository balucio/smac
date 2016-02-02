<div class="col-xs-4 col-md-2 text-right">
    <h5><abbr title="Temperatura antigelo">T</abbr><sub>
        <span class="wi wi-snowflake-cold" aria-hidden="true"></span></sub>
    </h5>
</div>
<div class="col-xs-8 col-md-4"><h5>
    {{#decorateTemperature}}{{antigelo}}{{/decorateTemperature}}
    <span class="wi wi-celsius fa-1x" aria-hidden="true"></span>
</h5></div>
{{#temperature}}
<div class="col-xs-4 col-md-2 text-right" id="t_name_{{t_id}}"><h5>T<sub>{{t_id}}</sub></h5></div>
<div class="col-xs-8 col-md-4"><h5>
    {{#decorateTemperature}}{{t_val}}{{/decorateTemperature}}
    <span class="wi wi-celsius fa-1x" aria-hidden="true"></span>
</h5></div>
{{/temperature}}