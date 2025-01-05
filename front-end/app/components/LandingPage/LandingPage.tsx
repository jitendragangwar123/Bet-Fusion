"use client";
import Link from "next/link";
import { useState } from "react";

function LandingPage() {
  const [showPopup, setShowPopup] = useState(false);

  const handlePopup = () => {
    setShowPopup(true);
    setTimeout(() => setShowPopup(false), 2000); 
  };

  return (
    <main className="relative min-h-screen overflow-hidden">
      <div
        className="absolute inset-0 w-full h-full bg-cover bg-center"
        style={{
          backgroundImage: 'url("/landing-page.svg")',
          filter: "blur(4px)",
        }}
      ></div>
      <div className="min-h-screen font-arcade bg-gradient-to-b from-purple-800 to-purple-900 flex flex-col items-center justify-center">
        <h1 className="text-white text-5xl font-extrabold mb-16 tracking-wider z-0">
          Feel the Thrill of Winning at{" "}
          <span className="text-yellow-400">LuckyLotto!</span>
        </h1>
        <div className="flex space-x-8">
          <Link href="/dice-roll">
            <div className="bg-yellow-400 w-80 p-4 h-100 flex flex-col items-center justify-center rounded-3xl shadow-xl cursor-pointer transform hover:scale-110 transition-all hover:shadow-3xl">
              <img src="/dice-image.png" alt="Roll Dice" className="w-30 h-30" />
              <p className="mt-6 text-purple-900 text-2xl font-bold tracking-wide uppercase">
                Roll Dice
              </p>
            </div>
          </Link>

          <div
            onClick={handlePopup} 
            className="bg-orange-400 w-80 p-4 h-100 flex flex-col items-center justify-center rounded-3xl shadow-xl cursor-pointer transform hover:scale-110 transition-all hover:shadow-3xl"
          >
            <img src="/coin-toss.png" alt="Coin Toss" className="w-30 h-30" />
            <p className="mt-6 text-purple-900 text-2xl font-bold tracking-wide uppercase">
              Coin Toss
            </p>
          </div>

          <div
            onClick={handlePopup}
            className="bg-blue-400 w-80 p-4 h-100 flex flex-col items-center justify-center rounded-3xl shadow-xl cursor-pointer transform hover:scale-110 transition-all hover:shadow-2xl"
          >
            <img src="/spin-wheel.png" alt="Spin the Wheel" className="w-30 h-30" />
            <p className="mt-6 text-purple-900 text-2xl font-bold tracking-wide uppercase">
              Spin the Wheel
            </p>
          </div>
        </div>
      </div>

      {showPopup && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center">
          <div className="bg-white p-6 rounded-lg shadow-lg text-center">
            <h2 className="text-2xl font-bold mb-4 text-purple-900">Coming Soon!</h2>
            <p className="text-gray-700">This Game will be available soon. Stay tuned!</p>
          </div>
        </div>
      )}
    </main>
  );
}

export default LandingPage;
