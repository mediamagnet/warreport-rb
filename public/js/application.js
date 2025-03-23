document.addEventListener("DOMContentLoaded", () => {
  const inputs = document.querySelectorAll('.admin-input');
  document.getElementById("pass-turn")?.addEventListener("click", e => {
    e.preventDefault();
    passTurn(); // ✅ Call your defined function
  });

  // Handle Score Buttons
  document.querySelectorAll("[data-update-score]").forEach(button => {
    button.addEventListener("click", () => {
      const player = button.dataset.player;
      const field = button.dataset.field;
      const value = parseInt(button.dataset.value, 10);
      if (player && field) {
        updateScore(player, field, value);
      }
    });
  });

  document.getElementById("update-turn")?.addEventListener("click", e => {
    e.preventDefault();
    const newTurn = document.getElementById("turn_input").value;
  
    fetch("/update_turn", {
      method: "POST",
      headers: {
        "Content-Type": "application/json"
      },
      body: JSON.stringify({ turn: newTurn })
    })
    .then(response => response.json())
    .then(data => {
      if (data.success) {
        console.log("Turn updated successfully.");
      } else {
        console.error("Failed to update turn.");
      }
    })
    .catch(error => console.error("Error updating turn:", error));
  });
  
  const passTurnBtn = document.getElementById("pass-turn");
  if (passTurnBtn) {
    passTurnBtn.addEventListener("click", (e) => {
      e.preventDefault();
      passTurn();
    });
  }

    // Mission Draw Buttons
    const drawP1 = document.getElementById("draw-mission-p1");
    const drawP2 = document.getElementById("draw-mission-p2");
  
    if (drawP1) {
      drawP1.addEventListener("click", () => drawMissions("Player 1"));
    }
  
    if (drawP2) {
      drawP2.addEventListener("click", () => drawMissions("Player 2"));
    }
  
  // Debounce function
  const debounce = (fn, delay = 300) => {
    let timer;
    return (...args) => {
      clearTimeout(timer);
      timer = setTimeout(() => fn.apply(this, args), delay);
    };
  };
  
  const sendUpdate = debounce((input) => {
    const field = input.dataset.field;
    const player = input.dataset.player;
    const value = input.value;
  
    const payload = player
      ? { player, field, value }
      : { field, value };
  
    fetch('/update_admin', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload)
    }).then(res => {
      if (!res.ok) console.error("Failed to update", field);
    });
  });
  
  inputs.forEach(input => {
    input.addEventListener('change', () => sendUpdate(input));
  });

  document.getElementById("pass-turn")?.addEventListener("click", e => {
  e.preventDefault();
  fetch("/pass_turn", { method: "POST" })
    .then(res => res.json())
    .then(data => {
      if (data.success) {
        console.log("✅ Turn advanced");
      } else {
        console.error("❌ Failed to pass turn");
      }
    });
});
  
  // Reset Game
  document.getElementById("reset-game")?.addEventListener("click", e => {
    e.preventDefault();
    fetch("/reset_game", { method: "POST" });
  });
  
  // End Game
  document.getElementById("end-game")?.addEventListener("click", e => {
    e.preventDefault();
    fetch("/end_game", { method: "POST" });
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

    if (field === "deployment" || field === "mission_rule" || field === "primary_mission") {
        requestData = { field: field, value: value };
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

// === WebSocket DOM Updates for Overlay ===
if (window.location.pathname === "/overlay") {
    const socket = new WebSocket(`ws://${location.host}/ws`);
  
    socket.onmessage = function (event) {
      const data = JSON.parse(event.data);
  
      const setText = (id, value) => {
        const el = document.getElementById(id);
        if (el) el.textContent = value;
      };
  
      const setImage = (id, src) => {
        const el = document.getElementById(id);
        if (el) el.src = src;
      };
  
      const p1 = data.player1;
      const p2 = data.player2;
      const isP1Attacker = p1.role === "Attacker";
  
      const attacker = isP1Attacker ? p1 : p2;
      const defender = isP1Attacker ? p2 : p1;
  
      // Text updates
      setText("attacker_name", attacker.name);
      setText("attacker_army", attacker.army);
      setText("attacker_detachment", attacker.detachment);
      setText("attacker_vp", attacker.primary + attacker.secondary);
      setText("attacker_cp", attacker.cp);
  
      setText("defender_name", defender.name);
      setText("defender_army", defender.army);
      setText("defender_detachment", defender.detachment);
      setText("defender_vp", defender.primary + defender.secondary);
      setText("defender_cp", defender.cp);
  
      setText("turn_number", `Turn ${data.turn}`);
      setText("mission_rule", `Mission Rule: ${data.mission_rule || "None"}`);
      setText("primary_mission", `Primary Mission: ${data.primary_mission || "None"}`);
  
      // Icons
      const attackerArmySlug = attacker.army?.toLowerCase().replace(/[\s_']/g, "-");
      const defenderArmySlug = defender.army?.toLowerCase().replace(/[\s_']/g, "-");
      setImage("attacker_icon", `/images/${attackerArmySlug}.png`);
      setImage("defender_icon", `/images/${defenderArmySlug}.png`);
  
      // Deployment map
      if (data.deployment) {
        setImage("deployment_map", `/images/deployments/PN_${data.deployment}.png`);
      }
      const passTurnButton = document.getElementById("pass-turn");
 
      // Winner
      const winnerOverlay = document.querySelector(".winner-overlay");
      if (winnerOverlay) {
        winnerOverlay.innerHTML = data.winner
          ? `<h1 class="text-light large centered">${data.winner} Wins!</h1>`
          : "";
      }
    };
  }
  if (data.game_over && data.winner) {
    document.getElementById("winner-overlay").style.display = "block";
    document.querySelector("#winner-overlay h1").textContent = `${data.winner} Wins!`;
  } else {
    document.getElementById("winner-overlay").style.display = "none";
  }
    