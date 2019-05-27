//= require jquery3

$(document).ready(function(){
	$('#submit_form').click(function(e){
		e.preventDefault();
		Rails.ajax({
		    type:"POST",
		    url:'/register',
		    data: "registration_data[first_name]=" + $('#first_name').val() + "&registration_data[middle_name]=" + $('#middle_name').val() + "&registration_data[last_name]=" + $('#last_name').val(),
		    success: function(response){
		    		// alert('Registration email sent!');
		    		$('#reset_form').click();
		    },
		    error: function (ex) {
	            // alert('Smth went wrong');
	        }
	    });
	    
	});
});

// $(document).ready(function(){
// 	window.onload = function(){ 

// 		$('#reset_form').click();
// 	};

// });