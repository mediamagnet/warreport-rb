document.addEventListener('DOMContentLoaded', function(){
    const contentDiv = document.getElementById('vp_atk');
    const data = sessionStorage.getItem('data');
    if(data){
        contentDiv.innerHTML = data;
    }
 });

function increaseATKvp() {
    var score = parseInt(document.getElementById('vp_atk').innerHTML);
    document.getElementById('vp_atk').innerHTML = score+1;
    
}