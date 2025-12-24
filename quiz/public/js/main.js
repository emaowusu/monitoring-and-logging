let timeLeft = 15; // seconds
    const timerEl = document.createElement("div");
    timerEl.id = "timer";
    timerEl.style.fontSize = "20px";
    timerEl.style.fontWeight = "bold";
    timerEl.style.marginBottom = "10px";
    document.getElementById("app").prepend(timerEl);

    const countdown = setInterval(() => {
        timerEl.textContent = `Remaining Time: ${timeLeft}s`;
        timeLeft--;

        if (timeLeft < 0) {
            clearInterval(countdown);
            alert("Time's up! View Scores.");
            window.location.href = "/result";
        }
    }, 1000);