import Header from "../components/Header";
import Footer from "../components/Footer";
import DiceRoll from "../components/DiceRoll/DiceRoll";

export default async function Page() {
  return (
    <div className=" ">
      <Header/>
      <DiceRoll />
      <Footer/>
    </div>
  );
}