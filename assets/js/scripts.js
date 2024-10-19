function renderCharts(data, container) {
  // Asset Allocation Chart
  const assetAllocationData = {
    labels: Object.keys(data.asset_allocation),
    datasets: [
      {
        data: Object.values(data.asset_allocation).map(Number),
        backgroundColor: [
          "#FF6384",
          "#36A2EB",
          "#FFCE56",
          "#4BC0C0",
          "#9966FF",
        ],
      },
    ],
  };
  const ctx1 = container
    .querySelector(".assetAllocationChart")
    .getContext("2d");
  new Chart(ctx1, {
    type: "pie",
    data: assetAllocationData,
  });

  // Holdings Chart
  const holdingsData = {
    labels: data.holdings.map((h) => h.description),
    datasets: [
      {
        data: data.holdings.map((h) => Number(h.weight)),
        backgroundColor: [
          "#FF6384",
          "#36A2EB",
          "#FFCE56",
          "#4BC0C0",
          "#9966FF",
        ],
      },
    ],
  };
  const ctx2 = container.querySelector(".holdingsChart").getContext("2d");
  new Chart(ctx2, {
    type: "pie",
    data: holdingsData,
  });

  // Sectors Chart
  const sectorsData = {
    labels: data.sectors.map((s) => s.sector),
    datasets: [
      {
        data: data.sectors.map((s) => Number(s.weight)),
        backgroundColor: [
          "#FF6384",
          "#36A2EB",
          "#FFCE56",
          "#4BC0C0",
          "#9966FF",
        ],
      },
    ],
  };
  const ctx3 = container.querySelector(".sectorsChart").getContext("2d");
  new Chart(ctx3, {
    type: "pie",
    data: sectorsData,
  });
}

function fetchData(container, symbols) {
  fetch(`/fetch_data?symbols=${encodeURIComponent(symbols)}`)
    .then((response) => {
      if (!response.ok) {
        throw new Error("Network response was not ok");
      }
      return response.json();
    })
    .then((data) => {
      const fetchedDataDiv = container.querySelector(".fetched-data");
      fetchedDataDiv.innerHTML = ""; // Clear previous data
      fetchedDataDiv.innerHTML = `
          <div id="charts-container" class="flex flex-col space-y-4">
            <div class="chart-section">
              <div class="flex items-center mb-2">
                <h4 class="text-md font-semibold">Asset Allocation</h4>
                <span class="tooltip" title="This chart shows the distribution of your assets across different categories.">
                  <span class="text-gray-500 ml-2 cursor-pointer">?</span>
                </span>
              </div>
              <canvas class="assetAllocationChart"></canvas>
            </div>
            <div class="chart-section">
              <div class="flex items-center mb-2">
                <h4 class="text-md font-semibold">Holdings</h4>
                <span class="tooltip" title="This chart displays the individual stocks or assets you own and their respective weights.">
                  <span class="text-gray-500 ml-2 cursor-pointer">?</span>
                </span>
              </div>
              <canvas class="holdingsChart"></canvas>
            </div>
            <div class="chart-section">
              <div class="flex items-center mb-2">
                <h4 class="text-md font-semibold">Sectors</h4>
                <span class="tooltip" title="This chart illustrates the sectors in which your assets are invested.">
                  <span class="text-gray-500 ml-2 cursor-pointer">?</span>
                </span>
              </div>
              <canvas class="sectorsChart"></canvas>
            </div>
          </div>
        `; // Add the canvas elements back for the new data
      renderCharts(data, fetchedDataDiv); // Pass the container for rendering charts
    })
    .catch((error) => {
      console.error("Error fetching data:", error);
      const fetchedDataDiv = container.querySelector(".fetched-data");
      fetchedDataDiv.innerHTML = `<p class="text-red-500">Error fetching data: ${error.message}</p>`;
    });
}

document.getElementById("fetch-data").onclick = function () {
  const symbols = document.getElementById("symbols-input").value;
  const container = this.closest(".carousel-container");
  fetchData(container, symbols);
};

document.getElementById("add-container").onclick = function () {
  const carousel = document.getElementById("carousel");
  const newContainer = document.createElement("div");
  newContainer.className =
    "carousel-container min-w-[400px] max-w-[400px] border rounded-lg p-4 shadow-lg flex-shrink-0 flex flex-col h-full";

  newContainer.innerHTML = `
      <h3 class="text-lg font-semibold mb-2">Enter Symbols</h3>
      <input type="text" placeholder="Enter symbols separated by commas (e.g., QQQ, SPY)" class="border rounded p-2 mb-2" />
      <button class="fetch-data bg-blue-500 text-white rounded p-2">Fetch Data</button>
      <div class="fetched-data mt-4 overflow-y-auto flex-grow" style="max-height: 100%;">
        <div id="charts-container" class="flex flex-col space-y-4">
          <div class="chart-section">
            <div class="flex items-center mb-2">
              <h4 class="text-md font-semibold">Asset Allocation</h4>
              <span class="tooltip" title="This chart shows the distribution of your assets across different categories.">
                <span class="text-gray-500 ml-2 cursor-pointer">?</span>
              </span>
            </div>
            <canvas class="assetAllocationChart"></canvas>
          </div>
          <div class="chart-section">
            <div class="flex items-center mb-2">
              <h4 class="text-md font-semibold">Holdings</h4>
              <span class="tooltip" title="This chart displays the individual stocks or assets you own and their respective weights.">
                <span class="text-gray-500 ml-2 cursor-pointer">?</span>
              </span>
            </div>
            <canvas class="holdingsChart"></canvas>
          </div>
          <div class="chart-section">
            <div class="flex items-center mb-2">
              <h4 class="text-md font-semibold">Sectors</h4>
              <span class="tooltip" title="This chart illustrates the sectors in which your assets are invested.">
                <span class="text-gray-500 ml-2 cursor-pointer">?</span>
              </span>
            </div>
            <canvas class="sectorsChart"></canvas>
          </div>
        </div>
      </div>
    `;

  carousel.insertBefore(newContainer, carousel.lastElementChild); // Add before the plus button

  // Add event listener for fetch button in new container
  newContainer.querySelector(".fetch-data").onclick = function () {
    const symbols = newContainer.querySelector("input").value;
    fetchData(newContainer, symbols);
  };
};
