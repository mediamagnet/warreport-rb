document.addEventListener("DOMContentLoaded", function () {
    const resetButton = document.getElementById("reset-game");
    const nextTurnButton = document.getElementById("next-turn");

    if (resetButton) {
        resetButton.addEventListener("click", resetGame);
    }
    document.querySelectorAll("[data-update-score]").forEach(button => {
        button.addEventListener("click", function () {
            const player = this.getAttribute("data-player");
            const field = this.getAttribute("data-field");
            const value = parseInt(this.getAttribute("data-value"));
            updateScore(player, field, value);
        });
    });
    document.querySelectorAll("#admin-form input, #admin-form select").forEach(element => {
        element.addEventListener("change", function () {
            const player = this.name.includes("player1") ? "Player 1" : "Player 2";
            const field = this.name.replace(/^player1_|^player2_/, ""); // Extracts field name
            updateGameState(player, field, this.value);
        });
    });

    if (nextTurnButton) {
        nextTurnButton.addEventListener("click", passTurn);
    }
});

function resetGame() {
    if (confirm("Are you sure you want to reset the game?")) {
        fetch("/reset_game", { method: "POST" })
            .then(() => {
                window.location.replace("/admin"); // Forces a full reload without parameters
            })
            .catch(() => alert("Error resetting game."));
    }
}

function updateGameState(player, field, value) {
    fetch("/update_game_state", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ player: player, [field]: value })
    })
    .then(response => response.json())
    .then(data => {
        if (!data.success) {
            alert("Error updating game state.");
        }
    })
    .catch(() => alert("Error updating game state."));
}

function passTurn() {
    fetch("/pass_turn", { method: "POST" })
        .then(response => response.json())
        .then(data => {
            if (data.success) {
                setTimeout(() => {
                    window.location.reload(); // Delay reload to ensure `game_state.json` updates
                }, 100); // 100ms delay to prevent data race
            } else {
                alert("Error advancing turn.");
            }
        })
        .catch(() => alert("Error advancing turn."));
}



function updateCP(gameState) {
    document.querySelector("[data-player='Player 1'][data-field='cp']").innerText = gameState.player1.cp;
    document.querySelector("[data-player='Player 2'][data-field='cp']").innerText = gameState.player2.cp;
}

function endGame() {
    fetch('/end_game', { method: 'POST' })
        .then(response => response.json())
        .then(data => {
            if (data.success) {
                location.reload(); // Refresh all views to show the Game Over screen
            } else {
                console.error('Error ending game:', data.message);
            }
        })
        .catch(error => console.error('Error ending game:', error));
}

function updateFactions() {
    const player1Faction = document.getElementById("player1_faction").value;
    const player2Faction = document.getElementById("player2_faction").value;

    fetch('/update_factions', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            player1_faction: player1Faction,
            player2_faction: player2Faction
        })
    })
    .then(response => response.json())
    .then(data => {
        if (data.success) {
            alert("Factions updated successfully!");
            location.reload(); // Refresh to update views
        }
    })
    .catch(error => console.error('Error updating factions:', error));
}


function updateScore(player, field, value) {
    fetch('/update_score', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ player, field, value })
    })
    .then(response => response.json())
    .then(data => {
        if (data.success) {
            location.reload();
        }
    })
    .catch(error => console.error('Error updating score:', error));
}