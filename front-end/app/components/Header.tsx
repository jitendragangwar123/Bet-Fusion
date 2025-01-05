"use client";
import { useEffect, useRef, useState } from "react";
import useTheme from "../hooks/useTheme";
import ThemeSwitch from "./Theme";
import Image from "next/image";
import Link from "next/link";

const Header = () => {
  const [openMenu, setOpenMenu] = useState(false);
  const { theme, changeTheme } = useTheme();
  const toggleMenu = () => {
    setOpenMenu((prev) => !prev);
  };

  return (
    <>
      <header className="w-full fixed backdrop-blur-2xl font-sans font-semibold  left-0 top-0 z-10 flex flex-wrap gap-2 py-1 px-2 md:py-4 md:px-10 justify-between items-center bg-gradient-to-b from-gray-100 to-purple-300 dark:from-gray-300 dark:to-purple-400">
        <div className="flex items-center gap-4">
          <a href="/">
            <div className="">
              <Image
                className="border border-transparent"
                src="/lucky-lotto.png"
                alt="logo"
                width={150}
                height={100}
              />
            </div>
          </a>
        </div>
        <div className="flex items-center font-arcade gap-8 ml-auto md:flex md:gap-8">
          <Link href="/" legacyBehavior>
            <a className="text-purple-700 text-2xl hover:underline">Home</a>
          </Link>
          <Link href="/landing-page" legacyBehavior>
            <a className="text-purple-700 text-2xl hover:underline pr-4">Play Arena</a>
          </Link>
        </div>
        <div className="hidden md:flex gap-8">
          <div className="flex items-center ">
            <w3m-button />
          </div>

          <ThemeSwitch
            className="flex md:hidden lg:hidden sm:hidden dark:transform-none transform dark:translate-none transition-all duration-500 ease-in-out"
            action={changeTheme}
            theme={theme}
            openMenu={openMenu}
          />
        </div>

        <div className="flex items-center md:hidden gap-8">
          <ThemeSwitch
            className="flex md:hidden dark:transform-none transform dark:translate-none transition-all duration-500 ease-in-out"
            action={changeTheme}
            theme={theme}
            openMenu={openMenu}
          />
          <button
            title="toggle menu"
            onClick={toggleMenu}
            className="flex flex-col gap-2 md:hidden"
          >
            <div
              className={`w-[1.5em] h-[2px] ${theme === "dark" ? "bg-[#ffffff]" : "bg-[#000000]"
                } rounded-full transition-all duration-300 ease-in-out ${openMenu
                  ? "rotate-45 translate-y-[0.625em]"
                  : "rotate-0 translate-y-0"
                }`}
            ></div>
            <div
              className={`w-[1.5em] h-[2px] ${theme === "dark" ? "bg-[#ffffff]" : "bg-[#000000]"
                } rounded-full transition-all duration-300 ease-in-out ${openMenu ? "opacity-0" : "opacity-100"
                }`}
            ></div>
            <div
              className={`w-[1.5em] h-[2px] ${theme === "dark" ? "bg-[#ffffff]" : "bg-[#000000]"
                } rounded-full transition-all duration-300 ease-in-out ${openMenu
                  ? "-rotate-45 translate-y-[-0.625em]"
                  : "rotate-0 translate-y-0"
                }`}
            ></div>
          </button>
        </div>

        <div
          className={`w-screen transition-all duration-300 ease-in-out grid ${openMenu
            ? "min-h-[4rem] grid-rows-[1fr] opacity-100"
            : "grid-rows-[0fr] opacity-0"
            } md:hidden`}
        >
          <div className="overflow-hidden">
            <div className="flex flex-wrap gap-8">
              <div className="flex items-center">
                <w3m-button />
              </div>
            </div>
          </div>
        </div>
      </header>
    </>
  );
};

export default Header;
