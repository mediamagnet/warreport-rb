score = 0;

document.addEventListener('DOMContentLoaded', function(){
    const contentDiv = document.getElementById('vp_atk');
    const data = sessionStorage.getItem('data');
    if(data){
        contentDiv.innerHTML = data;
    }
    console.log("hi");
 });

function increaseATKvp() {
    const ws = new WebSocket('ws://' + window.location.host + '/websocket');
    var score = parseInt(document.getElementById('vp_atk').innerHTML);
    document.getElementById('vp_atk').innerHTML = score+1;
    ws.onmessage = function(event) {
        console.log(event.data);
    };
    ws.send(score);
}

function decreaseATKvp() {
    var score = parseInt(document.getElementById('vp_atk').innerHTML);
    document.getElementById('vp_atk').innerHTML = score-1;
}

function updateATKOverlay() {
    const ws = new WebSocket('ws://' + window.location.host + '/websocket');
    ws.onmessage = function(event) {
        const atkVPDiv = document.getElementById('vp_atk1');
        atkVPDiv.innerHTML = event.data;
    };
}