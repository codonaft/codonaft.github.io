var yt_icon = '<svg height="100%" version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 68 48" width="100%"><path class="ytp-large-play-button-bg" d="M66.52,7.74c-0.78-2.93-2.49-5.41-5.42-6.19C55.79,.13,34,0,34,0S12.21,.13,6.9,1.55 C3.97,2.33,2.27,4.81,1.48,7.74C0.06,13.05,0,24,0,24s0.06,10.95,1.48,16.26c0.78,2.93,2.49,5.41,5.42,6.19 C12.21,47.87,34,48,34,48s21.79-0.13,27.1-1.55c2.93-0.78,4.64-3.26,5.42-6.19C67.94,34.95,68,24,68,24S67.94,13.05,66.52,7.74z" fill="#eb3223"></path><path d="M 45,24 27,14 27,34" fill="#fff"></path></svg>';

var yt_dark_icon = '<svg height="100%" version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 68 48" width="100%"><path class="ytp-large-play-button-bg" d="M66.52,7.74c-0.78-2.93-2.49-5.41-5.42-6.19C55.79,.13,34,0,34,0S12.21,.13,6.9,1.55 C3.97,2.33,2.27,4.81,1.48,7.74C0.06,13.05,0,24,0,24s0.06,10.95,1.48,16.26c0.78,2.93,2.49,5.41,5.42,6.19 C12.21,47.87,34,48,34,48s21.79-0.13,27.1-1.55c2.93-0.78,4.64-3.26,5.42-6.19C67.94,34.95,68,24,68,24S67.94,13.05,66.52,7.74z" fill="#212121" fill-opacity="0.8"></path><path d="M 45,24 27,14 27,34" fill="#fff"></path></svg>';

var ytdefer_players = [];

var ytdefer_defer_yt_api_ms = 3000;

var ytdefer_player_api_id = 'youtube_player_api';

function ytdefer_setup()
{
    var d = document;
    var els = d.getElementsByClassName('ytdefer');
    for(var i = 0; i < els.length; i++)
    {
        var e = els[i];
        var ds = e.getAttribute('data-src');
        var aspect_ratio_inverted = ytdefer_aspect_ratio_inverted(e);

        var w = e.clientWidth;
        var h = e.clientWidth * aspect_ratio_inverted;

        var dv = d.createElement('div');
        dv.id = 'ytdefer_vid'+i;
        dv.style.width = w+'px';
        dv.style.height = h+'px';
        dv.style.position = 'relative';
        dv.onresize = ytdefer_resize;
        e.appendChild(dv);

        var im = d.createElement('img');
        /*if (e.hasAttribute('data-alt'))
        {
            var alt = e.getAttribute('data-alt');
            im.alt = alt;
        }*/
        if (e.hasAttribute('data-title'))
        {
            var title = e.getAttribute('data-title');
            /*if (!e.hasAttribute('data-alt'))
            {
                im.alt = title;
            }*/
            var title_link = d.createElement('a');
            title_link.href = 'https://www.youtube.com/watch?v=' + ds;
            title_link.innerHTML = title;
            title_link.target = '_blank';
            title_link.rel = 'noopener';
            title_link.title = title;
            title_link.style.position = 'absolute';
            title_link.style.display = 'block';
            title_link.style.padding = '0.8em';
            title_link.style.paddingRight = '3em';
            title_link.style.fontSize = '1em';
            title_link.style.height = '4em';
            title_link.style.width = '100%';
            title_link.style.color = 'white';
            title_link.style.background = 'linear-gradient(to bottom, rgba(0, 0, 0, 0.5) 0%, rgba(0, 0, 0, 0) 100%)';
            title_link.style.whiteSpace = 'nowrap';
            title_link.style.overflow = 'hidden';
            title_link.style.textOverflow = 'ellipsis';
            dv.appendChild(title_link);
        }

        var res = '0';
        if (w > 480)
        {
            res = 'maxresdefault';
        }

        im.id = 'ytdefer_img'+i;
        if (i > 0)
        {
            im.loading = 'lazy';
        }
        im.style.width = '100%';
        im.style.height = '100%';
        im.style.objectFit = 'cover';
        //im.style.position = 'absolute';
        im.onclick = gen_ytdefer_clk(i);
        im.src = 'https://img.youtube.com/vi/'+ds+'/'+res+'.jpg';
        dv.appendChild(im);

        var bt = d.createElement('button');
        // https://stackoverflow.com/a/25357859/1192732
        bt.style.backgroundImage = "url(data:image/svg+xml;base64,"+window.btoa(yt_dark_icon)+")";
        bt.style.backgroundRepeat = 'no-repeat';
        bt.id = 'ytdefer_icon'+i;
        bt.setAttribute('aria-label', 'Play');
        bt.style.position = 'absolute';
        bt.style.border = '0';
        bt.style.backgroundColor = 'transparent';
        bt.style.pointerEvents = 'none';
        update_button(bt, e);
        dv.appendChild(bt);

        im.onmouseover = gen_mouseover(bt);
        im.onmouseout = gen_mouseout(bt);
    }
    /*if (els.length > 0 && typeof(YT) === 'undefined')
    {
        setTimeout(function() {
            maybe_load_player_api();
        }, ytdefer_defer_yt_api_ms);
    }*/
    //window.addEventListener('resize', ytdefer_resize);
    //window.dispatchEvent(new Event('resize'));
}

function maybe_load_player_api()
{
    var d = document;
    if (typeof(YT) === 'undefined' && d.getElementById(ytdefer_player_api_id) === null && d.getElementsByClassName('ytdefer').length > 0)
    {
        var js = d.createElement("script");
        js.id = ytdefer_player_api_id;
        js.type = "text/javascript";
        js.src = "https://www.youtube.com/player_api";
        d.body.appendChild(js);
    }
}

function ytdefer_resize()
{
    var d = document;
    var els = d.getElementsByClassName('ytdefer');
    for(var i = 0; i < els.length; i++)
    {
        var e = els[i];
        var aspect_ratio_inverted = ytdefer_aspect_ratio_inverted(e);
        var w = e.clientWidth;
        var h = e.clientWidth * aspect_ratio_inverted;
        var dv = d.getElementById('ytdefer_vid'+i);
        dv.style.width = w+'px';
        dv.style.height = h+'px';
        var ic = d.getElementById('ytdefer_icon'+i);
        if (null != ic)
        {
            update_button(ic, e);
        }
    }
}

//https://stackoverflow.com/a/30152957/1192732
function gen_mouseout(bt)
{
    return function()
    {
        bt.style.backgroundImage = "url(data:image/svg+xml;base64,"+window.btoa(yt_dark_icon)+")";
        document.body.style.cursor = null;
    }
}

function gen_mouseover(bt)
{
    return function()
    {
        maybe_load_player_api();
        bt.style.backgroundImage = "url(data:image/svg+xml;base64,"+window.btoa(yt_icon)+")";
        document.body.style.cursor = 'pointer';
    }
}

function gen_ytdefer_clk(i)
{
    return function()
    {
        if (typeof(YT) === 'undefined') {
            setTimeout(function() {
                add_player(i);
            }, ytdefer_defer_yt_api_ms);
        } else {
            add_player(i);
        }
    }
}

function add_player(i)
{
    var d = document;
    var el = d.getElementById('ytdefer_vid'+i);
    var vid_id = el.parentNode.getAttribute('data-src');
    var aspect_ratio_inverted = ytdefer_aspect_ratio_inverted(el.parentNode);
    var player = new YT.Player(el.id,
    {
        width: el.style.width,
        height: el.style.width * aspect_ratio_inverted,
        videoId: vid_id,
        playerVars: {
            start: el.parentNode.getAttribute('data-start'),
            rel: 0,
        },
        events:
        {
            'onReady': function(ev) { ev.target.playVideo() },
            'onStateChange': function(ev) {
                if (ev.data == YT.PlayerState.PLAYING) {
                    for (const p of ytdefer_players) {
                        if (p !== player) {
                            p.pauseVideo();
                        }
                    }
                }
            }
        }
    });
    ytdefer_players.push(player);
    document.body.style.cursor = null;
}

function ytdefer_aspect_ratio_inverted(element)
{
    var ratio_str = element.getAttribute('data-aspect-ratio') || '16:9';
    var ratio = ratio_str.split(':');
    var width = ratio[0];
    var height = ratio[1];
    return height/width;
}

function update_button(button, e)
{
    var w = e.clientWidth;
    var h = e.clientHeight;
    var ytdefer_ic_w = 0.114 * w;
    var ytdefer_ic_h = 0.144 * h;
    button.style.left = (w/2-ytdefer_ic_w/2)+'px';
    button.style.top = (h/2-ytdefer_ic_h/2)+'px';
    button.style.width = ytdefer_ic_w+'px';
    button.style.height = ytdefer_ic_h+'px';
}
