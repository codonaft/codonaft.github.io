document.addEventListener("DOMContentLoaded", function(event) {

    /*
    * Display the menu items on smaller screens
    */
    const pull = document.getElementById('pull');
    const menu = document.querySelector('nav ul');

    pull?.addEventListener('click', function(e) {
        menu?.classList.toggle('hide');
    });

    /*
    * Make the header images move on scroll
    */
    window.addEventListener('scroll', function() {
        const x = window.pageYOffset | document.body.scrollTop;
        const m = document.getElementById("main");
        const c = m?.style;

        if (c) {
          c.backgroundPosition = 'center ' + parseInt(-x/3) + 'px' + ', 0%, center top';
        }
    });
});
