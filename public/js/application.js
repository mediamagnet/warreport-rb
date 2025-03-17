document.addEventListener("DOMContentLoaded", function () {
    const resetButton = document.getElementById("reset-game");
    const nextTurnButton = document.getElementById("next-turn");
    const adminInputs = document.querySelectorAll(".admin-input");
    
    // fetchGameState();
    fetch("/secondary_missions.json")
    .then(response => response.json())
    .then(data => {
        populateMissionDropdowns(data.cards);
    })
    .catch(error => console.error("Error loading mission data:", error));

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

    document.querySelectorAll(".admin-input").forEach(input => {
        input.addEventListener("change", function () {
            const player = this.dataset.player || null;
            const field = this.dataset.field;
            const value = this.value;

            updateAdminField(player, field, value);

            // Force selected state update for dropdowns
            if (this.tagName === "SELECT") {
                this.querySelectorAll("option").forEach(option => {
                    option.removeAttribute("selected");
                });
                this.querySelector(`option[value="${value}"]`).setAttribute("selected", "selected");
            }
        });
    });
    
    document.getElementById("deployment-select")?.addEventListener("change", function () {
        updateGameState(null, "deployment", this.value);
    });

    document.getElementById("mission-rule-select")?.addEventListener("change", function () {
        updateGameState(null, "mission_rule", this.value);
    });
    

    adminInputs.forEach(input => {
        input.addEventListener("change", function () {
            updateAdminField(this.dataset.player, this.dataset.field, this.value);
        });
    });

    if (nextTurnButton) {
        nextTurnButton.addEventListener("click", passTurn);
    }

    document.addEventListener("DOMContentLoaded", function () {
        document.querySelectorAll("[data-draw-missions]").forEach(button => {
            button.addEventListener("click", function () {
                const player = this.getAttribute("data-player");
                drawMissions(player);
            });
        });

    
        document.querySelectorAll("[data-discard-mission]").forEach(button => {
            button.addEventListener("click", function () {
                const missionSlot = this.closest(".mission-card").getAttribute("data-slot");
                const player = this.closest(".mission-card").getAttribute("data-player");
                discardMission(player, missionSlot);
            });
        });
    });
});


function drawMissions(player) {
    fetch("/draw_missions", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ player: player })
    })
    .then(response => response.json())
    .then(data => {
        updateMissionDisplay(player, data.missions);
    })
    .catch(error => console.error("Error drawing missions:", error));
}

function updateMissionDisplay(player, missions) {
    missions.forEach((mission, index) => {
        let missionCard = document.querySelector(`[data-player="${player}"][data-slot="${index + 1}"]`);
        if (missionCard) {
            missionCard.querySelector(".mission-title").textContent = mission.name;
            missionCard.querySelector(".mission-description").textContent = mission.description;
        }
    });
}

function discardMission(player, slot) {
    fetch("/discard_mission", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ player: player, slot: slot })
    })
    .then(response => response.json())
    .then(data => {
        if (data.success) {
            updateMissionDisplay(player, data.missions);
        }
    })
    .catch(error => console.error("Error discarding mission:", error));
}

function updateMission(select) {
    const player = select.dataset.player;
    const missionKey = select.dataset.mission;
    const missionName = select.value;

    fetch("/secondary_missions.json")
        .then(response => response.json())
        .then(data => {
            const missionDescription = data.cards[missionName] || "No description available.";
            document.getElementById(`${player.toLowerCase()}_mission_description`).textContent = missionDescription;

            fetch("/update_mission", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ player, missionKey, missionName })
            });
        });
}

function resetGame() {
    fetch('/reset_game', { method: 'POST' })
        .then(response => response.json())
        .then(data => {
            if (data.success) {
                console.log("Game successfully reset.");

                // Hide modal & reset dismissal flag
                const modal = document.getElementById("game-over-modal");
                if (modal) {
                    modal.classList.add("hidden");
                }
                modalDismissed = false; // Allow modal to be shown again

                // Reload the page to reflect reset state
                location.reload();
            }
        })
        .catch(error => console.error("Error resetting game:", error));
}

// Fetch game state and update UI, but only show modal if it hasn’t been dismissed
// function fetchGameState() {
//    fetch("/game_state.json")
//        .then(response => response.json())
//        .then(data => {
//            const winnerText = document.querySelector(".winner-announcement h1");
//
//            if (data.winner && winnerText) {
//                winnerText.innerText = `${data.winner} Wins!`;
//            }
//        })
//        .catch(error => console.error("Error fetching game state:", error));
// }

function updateGameState(player, field, value) {
    let requestData = {};

    if (field === "deployment") {
        requestData = { field: "deployment", value: value };
    } else {
        requestData = { player: player, [field]: value };
    }

    console.log("🛠 Sending update:", requestData); // Debugging log

    fetch("/update_game_state", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(requestData)
    })
    .then(response => response.json())
    .then(data => {
        if (!data.success) {
            alert("Error updating game state.");
        } else {
            console.log("✅ Game state updated:", data);
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

function updateAdminField(player, field, value) {
    fetch("/update_admin", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
            player: player,
            [field]: value
        })
    })
    .then(response => response.json())
    .then(data => console.log("Updated game state:", data))
    .catch(error => console.error("Error updating game state:", error));
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

function populateMissionDropdowns(missions) {
    const dropdowns = ["player1_mission1", "player1_mission2", "player2_mission1", "player2_mission2"];
    dropdowns.forEach(dropdownId => {
        const dropdown = document.getElementById(dropdownId);
        dropdown.innerHTML = '<option value="">Select a Mission</option>'; // Default option
        Object.keys(missions).forEach(mission => {
            let option = document.createElement("option");
            option.value = mission;
            option.textContent = mission;
            dropdown.appendChild(option);
        });
    });
}

function updateMission(select) {
    const player = select.dataset.player;
    const missionKey = select.dataset.mission;
    const missionName = select.value;

    fetch("/secondary_missions.json")
        .then(response => response.json())
        .then(data => {
            const missionDescription = data.cards[missionName] || "No description available.";
            document.getElementById(`${player.toLowerCase()}_mission_description`).textContent = missionDescription;

            fetch("/update_mission", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ player, missionKey, missionName })
            });
        });
}