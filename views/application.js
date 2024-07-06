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
    var score = parseInt(document.getElementById('vp_atk').innerHTML);
    document.getElementById('vp_atk').innerHTML = score+1;
    var vpATK = [['attacker', score]]
    JSON.stringify(score);
    .get('/players', { vpATK: vpATK})
    
}

function decreaseATKvp() {
    var score = parseInt(document.getElementById('vp_atk').innerHTML);
    document.getElementById('vp_atk').innerHTML = score-1;
}