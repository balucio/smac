/** Jquery plugin to show modal */

(function ( $ ) {

	$.fn.showDeleteConfirm = function(header, body, callback) {

		// Visualizzo il pannello di conferma
		self = this;
		this.modal();

		this.on('hidden.bs.modal', function () {
				$(this).data('bs.modal', null);
		});

		// Popolo il modale e imposto la callback
		this.find('div.modal-header').html($( '#' + header ).html());
		this.find('div.modal-body').html($( '#' + body ).html());
		if (typeof callback === 'function') {
			this.find('a.btn-ok').one( 'click', function(e) {
				e.preventDefault();
				callback();
				self.modal('hide');
			});
		} else {
			this.find('a.btn-ok').addClass('hidden');
		}

		return this;
	};
}( jQuery ));
